//
//  SleepTime.swift
//  Sleeponomics
//
//  Created by Christofer Roth on 2015-09-02.
//  Copyright (c) 2015 Prototyp. All rights reserved.
//

import Foundation

struct SleepTime {
    static let timeFlags = NSCalendarUnit.CalendarUnitHour | NSCalendarUnit.CalendarUnitMinute

    var hour: Int
    var minute: Int

    static func fromDate(date: NSDate) -> SleepTime {
        let calendar = NSCalendar.currentCalendar()
        let comps = calendar.components(timeFlags, fromDate: date)

        return SleepTime(hour: comps.hour, minute: comps.minute)
    }

    static func decode(dict: [String: Int]) -> SleepTime {
        return SleepTime(hour: dict["hour"]!, minute: dict["minute"]!)
    }

    func encode() -> [String: Int] {
        return ["hour": hour, "minute": minute]
    }

    func toDate() -> NSDate {
        let calendar = NSCalendar.currentCalendar()

        let comps = NSDateComponents()
        comps.hour = hour
        comps.minute = minute

        return calendar.dateFromComponents(comps) as NSDate!
    }

    func toUTCDate() -> NSDate {
        let calendar = NSCalendar.currentCalendar()
        calendar.timeZone = NSTimeZone(abbreviation: "UTC") as NSTimeZone!

        let comps = NSDateComponents()
        comps.hour = hour
        comps.minute = minute

        return calendar.dateFromComponents(comps) as NSDate!
    }

    func toString() -> String {
        let date = toDate()
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeStyle = .ShortStyle
        return dateFormatter.stringFromDate(date)
    }
}
