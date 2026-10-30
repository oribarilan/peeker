import Foundation
import Testing

@Suite(.serialized) struct PluginProcessTests {
    let process = PluginProcess(entry: TestProducts.entry(id: "test", executable: "test-plugin", types: []), idleSeconds: 0.2)

    @Test func repliesToARequest() async throws {
        let reply = try await process.request(.open(path: "echo", maxPixels: 1), doc: "a", timeout: .seconds(5))
        #expect(reply.sidebar?.isEmpty == false)
    }

    @Test func crashFailsThePendingRequestAndNotifiesAttachedDocuments() async {
        var crashed: String?
        process.attach("a") { crashed = $0 }
        await #expect(throws: PluginFailure.self) { try await process.request(.open(path: "crash", maxPixels: 1), doc: "a", timeout: .seconds(5)) }
        #expect(crashed?.contains("stopped") == true)
    }

    @Test func hangIsKilledAtTheTimeout() async {
        let started = ContinuousClock.now
        do { _ = try await process.request(.open(path: "hang", maxPixels: 1), doc: "a", timeout: .milliseconds(300)); Issue.record("no timeout") }
        catch { #expect(error.message.contains("didn't respond")) }
        #expect(ContinuousClock.now - started < .seconds(2))
        #expect(!process.isRunning)
    }

    @Test func malformedReplyFailsInsteadOfWaitingForever() async {
        do { _ = try await process.request(.open(path: "garbage", maxPixels: 1), doc: "a", timeout: .seconds(5)); Issue.record("accepted garbage") }
        catch { #expect(error.message.contains("couldn't read")) }
    }

    @Test func restartsAfterACrash() async throws {
        _ = try? await process.request(.open(path: "crash", maxPixels: 1), doc: "a", timeout: .seconds(5))
        _ = try await process.request(.open(path: "echo", maxPixels: 1), doc: "b", timeout: .seconds(5))
        #expect(process.isRunning)
    }

    @Test func stopsWhenIdleAndStartsAgainOnDemand() async throws {
        process.attach("a") { _ in }
        _ = try await process.request(.open(path: "echo", maxPixels: 1), doc: "a", timeout: .seconds(5))
        process.detach("a")
        try await Task.sleep(for: .seconds(1))
        #expect(!process.isRunning)
        _ = try await process.request(.open(path: "echo", maxPixels: 1), doc: "b", timeout: .seconds(5))
        #expect(process.isRunning)
    }

    @Test func stderrOutputDoesNotDisturbReplies() async throws {
        let reply = try await process.request(.open(path: "stderr", maxPixels: 1), doc: "a", timeout: .seconds(5))
        #expect(reply.sidebar?.isEmpty == false)
    }

    @Test func timeoutNotifiesAttachedDocuments() async {
        var stopped: String?
        process.attach("a") { stopped = $0 }
        _ = try? await process.request(.open(path: "hang", maxPixels: 1), doc: "a", timeout: .milliseconds(300))
        #expect(stopped?.contains("didn't respond") == true)
    }

    @Test func aFailureCallbackCanStartTheNextRequest() async {
        let next = await withCheckedContinuation { (done: CheckedContinuation<Result<Reply, PluginFailure>, Never>) in
            process.send(.open(path: "crash", maxPixels: 1), doc: "a", timeout: .seconds(5)) { [process] _ in
                process.send(.open(path: "echo", maxPixels: 1), doc: "a", timeout: .seconds(5)) { done.resume(returning: $0) }
            }
        }
        #expect((try? next.get())?.sidebar?.isEmpty == false)
    }
}
