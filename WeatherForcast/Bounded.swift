// File: Int+Bounded.swift
import Foundation

/// Constrain an integer to a `ClosedRange`.  
/// Negative values are clamped to the lower bound, values higher than the upper
/// bound are clamped to the upper bound.
extension Int {
    func bounded(to range: ClosedRange<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
