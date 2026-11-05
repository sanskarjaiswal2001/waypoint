import Darwin
import Foundation

/// Elapsed seconds include device sleep and do not change with the wall clock.
public enum ElapsedClock {
    public static var now: TimeInterval { Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000 }
}
