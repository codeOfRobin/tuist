import Foundation
import RxSwift
import TuistGraph
import XCTest

@testable import TuistCache
@testable import TuistCacheTesting
@testable import TuistSupportTesting

final class CacheTests: TuistUnitTestCase {
    var firstCache: MockCacheStorage!
    var secondCache: MockCacheStorage!
    var subject: TuistCache.Cache!

    override func setUp() {
        super.setUp()

        firstCache = MockCacheStorage()
        secondCache = MockCacheStorage()
        let cacheStorageProvider = MockCacheStorageProvider(config: Config.test())
        cacheStorageProvider.storagesStub = [firstCache, secondCache]
        subject = Cache(storageProvider: cacheStorageProvider)
    }

    override func tearDown() {
        super.tearDown()
        firstCache = nil
        secondCache = nil
        subject = nil
    }

    func test_exists_when_in_first_cache_does_not_check_second_and_returns_true() {
        firstCache.existsStub = { hash in
            XCTAssertEqual(hash, "1234")
            return true
        }
        secondCache.existsStub = { _ in
            XCTFail("Second cache should not be checked if first hits")
            return false
        }
        XCTAssertTrue(try subject.exists(hash: "1234").toBlocking().single())
    }

    func test_exists_when_in_second_cache_checks_both_and_returns_true() {
        firstCache.existsStub = { hash in
            XCTAssertEqual(hash, "1234")
            return false
        }
        secondCache.existsStub = { hash in
            XCTAssertEqual(hash, "1234")
            return true
        }
        XCTAssertTrue(try subject.exists(hash: "1234").toBlocking().single())
    }

    func test_exists_when_not_in_cache_checks_both_and_returns_false() {
        firstCache.existsStub = { hash in
            XCTAssertEqual(hash, "1234")
            return false
        }
        secondCache.existsStub = { hash in
            XCTAssertEqual(hash, "1234")
            return false
        }
        XCTAssertFalse(try subject.exists(hash: "1234").toBlocking().single())
    }

    func test_fetch_when_in_first_cache_does_not_check_second_and_returns_path() {
        firstCache.fetchStub = { hash in
            XCTAssertEqual(hash, "1234")
            return "/Absolute/Path"
        }
        secondCache.fetchStub = { _ in
            XCTFail("Second cache should not be checked if first hits")
            throw TestError("")
        }
        XCTAssertEqual(try subject.fetch(hash: "1234").toBlocking().single(), "/Absolute/Path")
    }

    func test_fetch_when_in_second_cache_checks_both_and_returns_path() {
        firstCache.fetchStub = { hash in
            XCTAssertEqual(hash, "1234")
            throw TestError("")
        }
        secondCache.fetchStub = { hash in
            XCTAssertEqual(hash, "1234")
            return "/Absolute/Path"
        }
        XCTAssertEqual(try subject.fetch(hash: "1234").toBlocking().single(), "/Absolute/Path")
    }

    func test_fetch_when_not_in_cache_checks_both_and_throws() {
        firstCache.fetchStub = { hash in
            XCTAssertEqual(hash, "1234")
            throw TestError("")
        }
        secondCache.fetchStub = { hash in
            XCTAssertEqual(hash, "1234")
            throw TestError("")
        }
        XCTAssertThrowsSpecific(
            try subject.fetch(hash: "1234").toBlocking().single(),
            TestError("")
        )
    }
}
