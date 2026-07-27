import Foundation

/// 複数本指の同時タップ（3本指 / 4本指）を検出する状態機械。
///
/// 入力は `HoldTapRecognizer` と同じタッチイベント1回ぶんのスナップショット集合。
/// 「全指がほぼ同時に着地し、ほとんど動かず、短時間で全指が離れる」場合のみ
/// タップと判定する。移動量と接地時間で絞ることで、Mission Control 等の
/// スワイプ開始をタップと誤判定しない。
@MainActor
final class MultiFingerTapRecognizer {
    // MARK: - 調整可能な閾値

    /// 最初の指の着地から最後の指の着地までの最大間隔（これを超えたら同時着地ではない）
    static let maxLandingSpread: TimeInterval = 0.10
    /// 最初の指の着地から全指離脱までの最長時間（長押し・ホールドとの区別）
    static let maxTapDuration: TimeInterval = 0.35
    /// 各指の許容移動量（正規化座標、スワイプ・スクロールとの区別）
    static let movementTolerance: Double = 0.03
    /// 全指の平均移動ベクトルの許容量（正規化座標）。タップの手ブレは方向がばらけて
    /// 平均が相殺されるが、スワイプは全指が同方向に動くため僅かな移動でも平均に残る。
    /// システムのスワイプ判定は movementTolerance より鋭敏に反応するため、
    /// 個別の移動量チェックだけでは短いスワイプをタップと誤判定しうる
    static let coherentMovementTolerance: Double = 0.015

    // MARK: - 内部状態

    /// このジェスチャー中に現れたタッチ1本ぶんの追跡レコード（離脱後も全指離脱まで保持する）
    private struct TrackedTouch {
        let startX: Double
        let startY: Double
        var lastX: Double
        var lastY: Double
        var hasEnded = false

        /// 接地位置からの移動量（正規化座標）
        var displacement: Double {
            ((lastX - startX) * (lastX - startX) + (lastY - startY) * (lastY - startY)).squareRoot()
        }
    }

    private enum State {
        /// タッチなし
        case idle
        /// 1本以上が接地中で、まだタップの可能性が残っている
        case gathering(firstLandingAt: TimeInterval)
        /// 失格。全指が離れるまでこの状態に留まる
        case invalid
    }

    private var state: State = .idle
    /// このジェスチャー中に現れた全タッチ。指の本数の確定に離脱済みも数えるため、
    /// 削除は全指離脱時にまとめて行う
    private var tracked: [String: TrackedTouch] = [:]

    nonisolated init() {}

    // MARK: - 認識

    /// タッチイベント1回ぶんのスナップショット集合を処理し、タップが確定したらジェスチャーを返す。
    /// - Parameters:
    ///   - touches: イベントに含まれる全タッチ。空の場合は無視する（タッチ情報を持たないイベントが混ざるため）
    ///   - timestamp: イベントのタイムスタンプ（単調増加であれば基準は問わない）
    func recognize(touches: [TouchSnapshot], timestamp: TimeInterval) -> GestureType? {
        guard !touches.isEmpty else { return nil }

        let newIDs = updateTracked(with: touches)
        markEnded(from: touches)

        let activeCount = tracked.values.count(where: { !$0.hasEnded })

        var emitted: GestureType?

        switch state {
        case .idle:
            if !newIDs.isEmpty {
                state = .gathering(firstLandingAt: timestamp)
            }

        case .gathering(let firstLandingAt):
            let elapsed = timestamp - firstLandingAt
            if tracked.count > 4 {
                // 5本以上はタップではない
                state = .invalid
            } else if !newIDs.isEmpty && tracked.values.contains(where: { $0.hasEnded }) {
                // 離脱済みの指がある状態での新規着地＝指のバウンド。離脱済みも本数に数えるため、
                // そのまま続けると 2本指タップが3本指タップに化ける
                state = .invalid
            } else if !newIDs.isEmpty && elapsed > Self.maxLandingSpread {
                // 後着の指が遅すぎる（ホールドタップや順次着地）
                state = .invalid
            } else if tracked.values.contains(where: { $0.displacement > Self.movementTolerance }) {
                // いずれかの指が動いた（スワイプ・スクロール・ピンチ）
                state = .invalid
            } else if meanMovementMagnitude > Self.coherentMovementTolerance {
                // 全指が同方向に動いている（短いスワイプの開始）
                state = .invalid
            } else if elapsed > Self.maxTapDuration {
                // 接地が長すぎる（ホールド）。全指離脱済みでも発火させない
                state = .invalid
            } else if activeCount == 0 {
                // 全指が時間内に離脱: 指の本数で確定
                switch tracked.count {
                case 3: emitted = .threeTap
                case 4: emitted = .fourTap
                default: break  // 1〜2本は対象外（ホールドタップ等は別の認識器が担う）
                }
            }

        case .invalid:
            break
        }

        // 全指離脱で常に初期状態へ戻す（発火後の掃除・失格状態の解除）
        if activeCount == 0 {
            state = .idle
            tracked.removeAll()
        }

        return emitted
    }

    /// ピンチ開始など、外部要因で認識を中断する（接地中の指があれば全指離脱まで失格扱い）
    func interrupt() {
        state = tracked.isEmpty ? .idle : .invalid
    }

    /// 全指の移動ベクトルの平均の大きさ（正規化座標）
    private var meanMovementMagnitude: Double {
        guard !tracked.isEmpty else { return 0 }
        let n = Double(tracked.count)
        let meanDX = tracked.values.reduce(0) { $0 + ($1.lastX - $1.startX) } / n
        let meanDY = tracked.values.reduce(0) { $0 + ($1.lastY - $1.startY) } / n
        return (meanDX * meanDX + meanDY * meanDY).squareRoot()
    }

    // MARK: - タッチ追跡

    /// スナップショットで追跡テーブルを更新し、このイベントで新たに現れたタッチの ID を返す
    private func updateTracked(with touches: [TouchSnapshot]) -> Set<String> {
        var newIDs: Set<String> = []
        for touch in touches {
            if var record = tracked[touch.id] {
                record.lastX = touch.x
                record.lastY = touch.y
                tracked[touch.id] = record
            } else {
                // began 以外で初めて現れた場合も防御的にこのイベントから追跡する
                tracked[touch.id] = TrackedTouch(
                    startX: touch.x, startY: touch.y,
                    lastX: touch.x, lastY: touch.y
                )
                newIDs.insert(touch.id)
            }
        }
        return newIDs
    }

    /// このイベントで終了したタッチを離脱済みにする。
    /// スナップショットに現れない追跡中 ID も終了扱いにする（ended の取り逃しへの防御）
    private func markEnded(from touches: [TouchSnapshot]) {
        for touch in touches where touch.phase == .ended || touch.phase == .cancelled {
            tracked[touch.id]?.hasEnded = true
        }
        let presentIDs = Set(touches.map(\.id))
        for id in tracked.keys where !presentIDs.contains(id) {
            tracked[id]?.hasEnded = true
        }
    }
}
