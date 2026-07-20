import Testing
@testable import Notch

@Test func parsesSupportedTimecodes() {
    #expect(Timecode.seconds(from: "83.45") == 83.45)
    #expect(Timecode.seconds(from: "01:23.450") == 83.45)
    #expect(Timecode.seconds(from: "1:02:03.5") == 3_723.5)
}

@Test func rejectsInvalidTimecodes() {
    #expect(Timecode.seconds(from: "abc") == nil)
    #expect(Timecode.seconds(from: "1:2:3:4") == nil)
}

@Test func formatsTimecode() {
    #expect(Timecode.string(from: 83.45) == "01:23.450")
}
