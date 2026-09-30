#if os(iOS)
    import Foundation
    import Libbox
    import notify

    final class ScreenStateObserver {
        private let queue = DispatchQueue(label: "io.nekohasekai.sfamt.screen-state")
        private var displayToken: Int32 = -1
        private var lockToken: Int32 = -1

        init(commandServer: LibboxCommandServer) {
            notify_register_dispatch("com.apple.iokit.hid.displayStatus", &displayToken, queue) { token in
                var state: UInt64 = 0
                notify_get_state(token, &state)
                // 旧版 dev-mitm Libbox 无 recordScreenState API，暂不调用
                // commandServer.recordScreenState(state == 1)
                if state == 1 {
                    commandServer.wakeNow()
                }
            }
            notify_register_dispatch("com.apple.springboard.lockstate", &lockToken, queue) { token in
                var state: UInt64 = 0
                notify_get_state(token, &state)
                // 旧版 dev-mitm Libbox 无 recordLockState API，暂不调用
                // commandServer.recordLockState(state == 1)
            }
        }

        func cancel() {
            notify_cancel(displayToken)
            notify_cancel(lockToken)
        }
    }
#endif
