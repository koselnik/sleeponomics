//
//  ColorConfiguration.swift
//  Sleeponomics
//
//  Created by Christofer Roth on 2015-09-03.
//  Copyright (c) 2015 Prototyp. All rights reserved.
//

import Foundation

struct LightSettings {
    let hue: Int
    let brightness: Int
    let saturation: Int
    let turnOff: Bool
}

struct ColorConfiguration {
    static func sunset() -> LightSettings {
        return LightSettings(hue: 5462, brightness: 1, saturation: 255, turnOff: true)
    }

    static func sunrise() -> LightSettings {
        return LightSettings(hue: 30000, brightness: 254, saturation: 254, turnOff: false)
    }
}