import XCTest
@testable import SSHGuard

@MainActor
final class StateManagerTests: XCTestCase {
    var tempDirectory: URL!
    var stateManager: StateManager!

    override func setUp() async throws {
        // Create temp directory for test state file
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let testStateFile = tempDirectory.appendingPathComponent("test-state.json")
        stateManager = StateManager(stateFilePath: testStateFile)
    }

    override func tearDown() async throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testInitialState() async {
        XCTAssertEqual(stateManager.state.version, "1.0")
        XCTAssertEqual(stateManager.state.hosts.count, 0)
        XCTAssertEqual(stateManager.state.pending.count, 0)
    }

    func testAddHost() async {
        let host = Host(
            id: "test-host",
            ip: "10.71.1.8",
            user: "rico",
            state: .allowed,
            note: "Test host"
        )

        await stateManager.upsertHost(host)

        XCTAssertEqual(stateManager.state.hosts.count, 1)
        XCTAssertEqual(stateManager.state.hosts.first?.id, "test-host")
        XCTAssertEqual(stateManager.state.hosts.first?.state, .allowed)
    }

    func testUpdateHostState() async {
        let host = Host(id: "test-host", ip: "10.71.1.8", state: .ask)
        await stateManager.upsertHost(host)

        await stateManager.updateHostState(id: "test-host", newState: .allowed)

        XCTAssertEqual(stateManager.state.hosts.first?.state, .allowed)
    }

    func testCycleHostState() async {
        let host = Host(id: "test-host", ip: "10.71.1.8", state: .blocked)
        await stateManager.upsertHost(host)

        // blocked → ask
        await stateManager.cycleHostState(id: "test-host")
        XCTAssertEqual(stateManager.state.hosts.first?.state, .ask)

        // ask → allowed
        await stateManager.cycleHostState(id: "test-host")
        XCTAssertEqual(stateManager.state.hosts.first?.state, .allowed)

        // allowed → blocked
        await stateManager.cycleHostState(id: "test-host")
        XCTAssertEqual(stateManager.state.hosts.first?.state, .blocked)
    }

    func testRemoveHost() async {
        let host = Host(id: "test-host", ip: "10.71.1.8")
        await stateManager.upsertHost(host)

        XCTAssertEqual(stateManager.state.hosts.count, 1)

        await stateManager.removeHost(id: "test-host")

        XCTAssertEqual(stateManager.state.hosts.count, 0)
    }

    func testAddPendingHost() async {
        let pending = PendingHost(ip: "10.71.20.99", user: "root")
        await stateManager.addPendingHost(pending)

        XCTAssertEqual(stateManager.pendingCount, 1)
        XCTAssertEqual(stateManager.state.pending.first?.ip, "10.71.20.99")
    }

    func testAuthorizePendingHost() async {
        let pending = PendingHost(ip: "10.71.20.99", user: "root")
        await stateManager.addPendingHost(pending)

        await stateManager.authorizePendingHost(ip: "10.71.20.99", state: .allowed)

        // Pending should be removed
        XCTAssertEqual(stateManager.pendingCount, 0)

        // Host should be added
        XCTAssertEqual(stateManager.state.hosts.count, 1)
        XCTAssertEqual(stateManager.state.hosts.first?.state, .allowed)
        XCTAssertEqual(stateManager.state.hosts.first?.ip, "10.71.20.99")
    }

    func testFindHostByIPOrHostname() {
        let host = Host(id: "test", hostname: "proxmox02", ip: "10.71.1.8")
        stateManager.state.hosts.append(host)

        XCTAssertNotNil(stateManager.state.findHost(byIPOrHostname: "10.71.1.8"))
        XCTAssertNotNil(stateManager.state.findHost(byIPOrHostname: "proxmox02"))
        XCTAssertNil(stateManager.state.findHost(byIPOrHostname: "unknown"))
    }

    func testPersistence() async throws {
        let host = Host(id: "test-host", ip: "10.71.1.8", state: .allowed)
        await stateManager.upsertHost(host)

        // Reload from file
        await stateManager.reload()

        XCTAssertEqual(stateManager.state.hosts.count, 1)
        XCTAssertEqual(stateManager.state.hosts.first?.id, "test-host")
    }
}
