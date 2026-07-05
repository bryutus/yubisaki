import Foundation

/// NSTouch から抽出した1本指ぶんのスナップショット。
/// AppKit 非依存の値型にすることで、合成データによるユニットテストを可能にする。
struct TouchSnapshot: Sendable, Equatable {
    enum Phase: Sendable {
        case began, moved, stationary, ended, cancelled
    }

    /// NSTouch.identity を文字列化した安定キー（タッチの接地〜離脱の間は不変）
    let id: String
    let phase: Phase
    /// トラックパッド正規化座標（原点は左下、0.0〜1.0）
    let x: Double
    let y: Double
}

/// チップタップ（1本指を置いたまま、別の指で左右どちらかを短くタップ）を検出する状態機械。
///
/// 入力はタッチイベント1回ぶんのスナップショット集合。タイマーは使わず、
/// 失格・発火の判定はすべて次のタッチイベント到着時に評価する
/// （タップ指の離脱は必ずイベントを生むため、イベント駆動で完結する）。
@MainActor
final class TipTapRecognizer {
    // MARK: - 調整可能な閾値

    /// タップ着地前に休止指が接地しているべき最短時間（2本指同時タップとの区別）
    static let minRestDuration: TimeInterval = 0.10
    /// タップ指が接地してから離すまでの最長時間
    static let maxTapDuration: TimeInterval = 0.30
    /// タップ指の許容移動量（正規化座標、スクロールとの区別）
    static let tapMovementTolerance: Double = 0.03
    /// 休止指の許容移動量（正規化座標）
    static let restMovementTolerance: Double = 0.05
    /// 左右判定に必要な最小X距離（曖昧なタップの誤発火防止）
    static let minHorizontalSeparation: Double = 0.08
    /// 発火後の再発火抑止時間。指のバウンド等による二重発火だけを防げばよいので、
    /// 意図的な連続チップタップ（最速でも 0.15s 間隔程度）を妨げない短さにする
    static let cooldown: TimeInterval = 0.10

    // MARK: - 内部状態

    /// 接地中のタッチ1本ぶんの追跡レコード
    private struct TrackedTouch {
        let startTime: TimeInterval
        let startX: Double
        let startY: Double
        var lastX: Double
        var lastY: Double

        /// 接地位置からの移動量（正規化座標）
        var displacement: Double {
            ((lastX - startX) * (lastX - startX) + (lastY - startY) * (lastY - startY)).squareRoot()
        }
    }

    private enum State {
        /// タッチなし
        case idle
        /// 1本だけ接地中（チップタップの「置き指」候補）
        case resting(restID: String)
        /// 置き指 + タップ指が接地中。タップ指の離脱を待っている
        case candidate(restID: String, tapID: String)
        /// 失格。全指が離れるまでこの状態に留まる
        case invalid
    }

    private var state: State = .idle
    private var tracked: [String: TrackedTouch] = [:]
    private var lastEmittedAt: TimeInterval?

    nonisolated init() {}

    // MARK: - 認識

    /// タッチイベント1回ぶんのスナップショット集合を処理し、チップタップが確定したらジェスチャーを返す。
    /// - Parameters:
    ///   - touches: イベントに含まれる全タッチ。空の場合は無視する（タッチ情報を持たないイベントが混ざるため）
    ///   - timestamp: イベントのタイムスタンプ（単調増加であれば基準は問わない）
    func recognize(touches: [TouchSnapshot], timestamp: TimeInterval) -> GestureType? {
        // タッチ情報を運ばないイベント（n=0）はフレーム欠落ではないので無視する
        guard !touches.isEmpty else { return nil }

        let newIDs = updateTracked(with: touches, timestamp: timestamp)
        let endedIDs = collectEndedIDs(from: touches)
        // 遷移判定には ended タッチの最終位置も使うため、削除は判定後に行う
        defer { endedIDs.forEach { tracked.removeValue(forKey: $0) } }

        let activeIDs = Set(tracked.keys).subtracting(endedIDs)

        // 3本以上の接地はチップタップではない
        if activeIDs.count > 2 {
            state = .invalid
        }

        var emitted: GestureType?

        switch state {
        case .idle:
            if activeIDs.count == 1, let only = activeIDs.first, newIDs.contains(only) {
                state = .resting(restID: only)
            } else if activeIDs.count >= 2 {
                // 同時に2本以上着地（2本指タップ/スクロール/ピンチの開始）
                state = .invalid
            }

        case .resting(let restID):
            if endedIDs.contains(restID) {
                // 置き指が離れた（ただの1本指タップ）。他の指が残っていれば異常系として失格
                state = activeIDs.isEmpty ? .idle : .invalid
            } else if let rest = tracked[restID], rest.displacement > Self.restMovementTolerance {
                // 置き指が動いた（1本指ドラッグ）
                state = .invalid
            } else if let tapID = newIDs.first(where: { $0 != restID }) {
                let restDuration = timestamp - (tracked[restID]?.startTime ?? timestamp)
                let cooldownElapsed = lastEmittedAt.map { timestamp - $0 >= Self.cooldown } ?? true
                if restDuration >= Self.minRestDuration && cooldownElapsed {
                    state = .candidate(restID: restID, tapID: tapID)
                }
                // 条件を満たさないタップ（置き指と同時着地・cooldown 中の連打）は候補にせず
                // 無視する。invalid にすると全指離脱まで復帰できず、置き指を残したままの
                // 連続チップタップが2打目以降できなくなるため、置き指状態を維持する。
            }

        case .candidate(let restID, let tapID):
            if endedIDs.contains(tapID) {
                // タップ指が離れた。置き指が無事ならチップタップ判定へ
                let restIntact = tracked[restID] != nil
                    && !endedIDs.contains(restID)
                    && tracked[restID]!.displacement <= Self.restMovementTolerance
                if restIntact, let tap = tracked[tapID], let rest = tracked[restID] {
                    let tapDuration = timestamp - tap.startTime
                    let separation = abs(tap.startX - rest.lastX)
                    if tapDuration <= Self.maxTapDuration
                        && tap.displacement <= Self.tapMovementTolerance
                        && separation >= Self.minHorizontalSeparation {
                        emitted = tap.startX < rest.lastX ? .twoTipTapLeft : .twoTipTapRight
                        lastEmittedAt = timestamp
                        // 置き指の基準位置を現在位置で取り直す。連続チップタップ中の
                        // わずかなドリフトが累積して失格（置き指が動いた扱い）になるのを防ぐ
                        tracked[restID] = TrackedTouch(
                            startTime: rest.startTime,
                            startX: rest.lastX, startY: rest.lastY,
                            lastX: rest.lastX, lastY: rest.lastY
                        )
                    }
                    // 発火の有無によらず、置き指が残っているので連続チップタップに備える
                    state = .resting(restID: restID)
                } else {
                    state = activeIDs.isEmpty ? .idle : .invalid
                }
            } else if endedIDs.contains(restID) {
                // タップ指より先に置き指が離れた
                state = .invalid
            } else if let tap = tracked[tapID], timestamp - tap.startTime > Self.maxTapDuration {
                // タップ指の長押し（2本指ホールド/スクロール開始）
                state = .invalid
            } else if let tap = tracked[tapID], tap.displacement > Self.tapMovementTolerance {
                state = .invalid
            } else if let rest = tracked[restID], rest.displacement > Self.restMovementTolerance {
                state = .invalid
            }

        case .invalid:
            break
        }

        // 失格状態は全指が離れたら解除
        if case .invalid = state, activeIDs.isEmpty {
            state = .idle
        }

        return emitted
    }

    /// ピンチ開始など、外部要因で認識を中断する（接地中の指があれば全指離脱まで失格扱い）
    func interrupt() {
        state = tracked.isEmpty ? .idle : .invalid
    }

    // MARK: - タッチ追跡

    /// スナップショットで追跡テーブルを更新し、このイベントで新たに現れたタッチの ID を返す
    private func updateTracked(with touches: [TouchSnapshot], timestamp: TimeInterval) -> Set<String> {
        var newIDs: Set<String> = []
        for touch in touches {
            switch touch.phase {
            case .began:
                tracked[touch.id] = TrackedTouch(
                    startTime: timestamp,
                    startX: touch.x, startY: touch.y,
                    lastX: touch.x, lastY: touch.y
                )
                newIDs.insert(touch.id)
            case .moved, .stationary:
                if var record = tracked[touch.id] {
                    record.lastX = touch.x
                    record.lastY = touch.y
                    tracked[touch.id] = record
                } else {
                    // began を取り逃した場合の防御（このイベントからの追跡になる）
                    tracked[touch.id] = TrackedTouch(
                        startTime: timestamp,
                        startX: touch.x, startY: touch.y,
                        lastX: touch.x, lastY: touch.y
                    )
                    newIDs.insert(touch.id)
                }
            case .ended, .cancelled:
                // 最終位置だけ反映（削除は recognize 側で判定後に行う）
                if var record = tracked[touch.id] {
                    record.lastX = touch.x
                    record.lastY = touch.y
                    tracked[touch.id] = record
                }
            }
        }
        return newIDs
    }

    /// このイベントで終了したタッチの ID を集める。
    /// スナップショットに現れない追跡中 ID も終了扱いにする（ended の取り逃しへの防御）
    private func collectEndedIDs(from touches: [TouchSnapshot]) -> Set<String> {
        var endedIDs: Set<String> = []
        for touch in touches where touch.phase == .ended || touch.phase == .cancelled {
            endedIDs.insert(touch.id)
        }
        let presentIDs = Set(touches.map(\.id))
        for id in tracked.keys where !presentIDs.contains(id) {
            endedIDs.insert(id)
        }
        return endedIDs
    }
}
