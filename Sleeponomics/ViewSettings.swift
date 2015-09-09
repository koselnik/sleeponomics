//
//  ViewSettings.swift
//  Sleeponomics
//
//  Created by Christofer Roth on 03/09/15.
//  Copyright (c) 2015 Prototyp. All rights reserved.
//

import Foundation

enum ViewStyle {
    case Night
    case Day
    case Alarm
}

struct ViewSettings {
    static func getViewStyle(timeOfDay: ViewStyle) -> ([String: UIColor], UIImage) {
        if timeOfDay == .Night {
            return getNighttimeView()
        }
        if timeOfDay == .Alarm {
            return getAlarmView()
        }
        return getDaytimeView()
    }

    static func getDaytimeView() -> ([String: UIColor], UIImage) {
        return (
            [
                "main": UIColor(red: 0.67058823529412, green: 0.8, blue: 0.7843137254902, alpha: 1.0),
                "cell": UIColor(red: 0.85490196078431, green: 0.95294117647059, blue: 0.94117647058824, alpha: 1.0)
            ], UIImage(named: "day-owl-1")!)
    }

    static func getNighttimeView() -> ([String: UIColor], UIImage) {
        return (
            [
                "main": UIColor(red: 0.05098039215686, green: 0.06666666666667, blue: 0.25098039215686, alpha: 1.0),
                "cell": UIColor(red: 0.55686274509804, green: 0.58823529411765, blue: 0.96078431372549, alpha: 1.0)
            ], UIImage(named: "star-owl-1")!)
    }

    static func getAlarmView() -> ([String: UIColor], UIImage) {
        return (
            [
                "main": UIColor(red: 0.97254901960784, green: 0.75686274509804, blue: 0.40392156862745, alpha: 1.0),
                "cell": UIColor(red: 0.97647058823529, green: 0.86274509803922, blue: 0.67450980392157, alpha: 1.0)
            ], UIImage(named: "alarm-owl")!)
    }
}
