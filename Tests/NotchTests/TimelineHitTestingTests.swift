import Foundation
import Testing
@testable import Notch

@Test func resolvesBothRegionBodiesAcrossTheirEntireDuration() {
    let first = ClipRegion(start: 44.863, end: 115.563, name: "Primero")
    let second = ClipRegion(start: 166, end: 243.75, name: "Segundo")
    let regions = [first, second]

    #expect(
        TimelineHitTesting.resolve(
            time: 45,
            edgeTolerance: 0.01,
            regions: regions,
            selectedRegionID: second.id
        ) == .body(first.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: 80,
            edgeTolerance: 0.01,
            regions: regions,
            selectedRegionID: second.id
        ) == .body(first.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: 115,
            edgeTolerance: 0.01,
            regions: regions,
            selectedRegionID: second.id
        ) == .body(first.id)
    )

    #expect(
        TimelineHitTesting.resolve(
            time: 167,
            edgeTolerance: 0.01,
            regions: regions,
            selectedRegionID: first.id
        ) == .body(second.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: 205,
            edgeTolerance: 0.01,
            regions: regions,
            selectedRegionID: first.id
        ) == .body(second.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: 243,
            edgeTolerance: 0.01,
            regions: regions,
            selectedRegionID: first.id
        ) == .body(second.id)
    )
}

@Test func resolvesEveryRegionEdge() {
    let first = ClipRegion(start: 44.863, end: 115.563, name: "Primero")
    let second = ClipRegion(start: 166, end: 243.75, name: "Segundo")
    let regions = [first, second]

    #expect(
        TimelineHitTesting.resolve(
            time: first.start,
            edgeTolerance: 0.1,
            regions: regions,
            selectedRegionID: nil
        ) == .start(first.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: first.end,
            edgeTolerance: 0.1,
            regions: regions,
            selectedRegionID: nil
        ) == .end(first.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: second.start,
            edgeTolerance: 0.1,
            regions: regions,
            selectedRegionID: nil
        ) == .start(second.id)
    )
    #expect(
        TimelineHitTesting.resolve(
            time: second.end,
            edgeTolerance: 0.1,
            regions: regions,
            selectedRegionID: nil
        ) == .end(second.id)
    )
}

@Test func resolvesEmptyTimelineAreas() {
    let first = ClipRegion(start: 44.863, end: 115.563, name: "Primero")
    let second = ClipRegion(start: 166, end: 243.75, name: "Segundo")

    #expect(
        TimelineHitTesting.resolve(
            time: 20,
            edgeTolerance: 0.1,
            regions: [first, second],
            selectedRegionID: first.id
        ) == .empty
    )
    #expect(
        TimelineHitTesting.resolve(
            time: 140,
            edgeTolerance: 0.1,
            regions: [first, second],
            selectedRegionID: first.id
        ) == .empty
    )
}
