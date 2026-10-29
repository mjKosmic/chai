import Foundation
import Testing
@testable import Chai

@Suite("InputReader lifecycle")
struct InputReaderTests {

    // MARK: - Helpers

    /// Wait for the reader's stream to finish, returning `false` on timeout.
    private func streamFinishes(_ reader: InputReader, within seconds: Double) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in reader.messages {}
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    private func makePipe() -> [Int32] {
        var fds: [Int32] = [0, 0]
        #expect(pipe(&fds) == 0)
        return fds
    }

    // MARK: - Tests

    @Test func stopFinishesStreamAndReleasesResources() async {
        let fds = makePipe()
        defer {
            Foundation.close(fds[0])
            Foundation.close(fds[1])
        }

        let reader = InputReader(fileDescriptor: fds[0])
        #expect(reader.lifecycleState == .idle)

        reader.start()
        #expect(reader.lifecycleState == .running)

        reader.stop()

        #expect(await streamFinishes(reader, within: 2))
        #expect(reader.lifecycleState == .finished)
    }

    @Test func repeatedStopIsIdempotent() async {
        let fds = makePipe()
        defer {
            Foundation.close(fds[0])
            Foundation.close(fds[1])
        }

        let reader = InputReader(fileDescriptor: fds[0])
        reader.start()

        reader.stop()
        reader.stop()
        reader.stop()

        #expect(await streamFinishes(reader, within: 2))
        #expect(reader.lifecycleState == .finished)
    }

    @Test func stopBeforeStartReleasesResources() async {
        let fds = makePipe()
        defer {
            Foundation.close(fds[0])
            Foundation.close(fds[1])
        }

        let reader = InputReader(fileDescriptor: fds[0])
        reader.stop()

        #expect(reader.lifecycleState == .finished)
        #expect(await streamFinishes(reader, within: 1))
    }

    @Test func startIsIgnoredAfterStop() async {
        let fds = makePipe()
        defer {
            Foundation.close(fds[0])
            Foundation.close(fds[1])
        }

        let reader = InputReader(fileDescriptor: fds[0])
        reader.stop()
        reader.start()

        #expect(reader.lifecycleState == .finished)
        #expect(await streamFinishes(reader, within: 1))
    }
}
