//
//  ViewController.swift
//  Sleeponomics
//
//  Created by Christofer Roth on 31/08/15.
//  Copyright (c) 2015 Prototyp. All rights reserved.
//

import Foundation
import UIKit

class HomeViewController: UITableViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    let timeFlags = NSCalendarUnit.CalendarUnitHour | NSCalendarUnit.CalendarUnitMinute
    let MAX_HUE: UInt32 = 65535
    let TRANSITION_TIME = 5 * 600 // 30 minutes (In 1/10 second)
    var transitionTime: Double!
    let SO_SCHEDULE_IDENTIFIER = "Sleeponomics schedule"
    var hiddenCells: [String] = ["wakeMeAtPickerCell", "sleepLengthPickerCell"]
    var currentBackgroundColor: UIColor?

    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate

    let defaults = NSUserDefaults.standardUserDefaults()

    let sleepLengthData: [Float] = [0.2, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12]

    var wakeMeAt: SleepTime!
    var sleepLengthValue: Float!

    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var syncButtonCell: UITableViewCell!
    @IBOutlet weak var wakeMeAtCell: UITableViewCell!
    @IBOutlet weak var owlImage: UIImageView!
    @IBOutlet weak var activeSwitch: UISwitch!
    @IBOutlet weak var activeSwitchCell: UITableViewCell!

    @IBOutlet weak var wakeMeAtInfoCell: UITableViewCell!
    @IBOutlet weak var wakeMeAtLabel: UILabel!
    @IBOutlet weak var wakeMeAtPicker: UIDatePicker!

    @IBOutlet weak var sleepLengthInfoCell: UITableViewCell!
    @IBOutlet weak var sleepLengthLabel: UILabel!
    @IBOutlet weak var sleepLengthPicker: UIPickerView!
    @IBOutlet weak var sleepLengthCell: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()

        transitionTime = -0.1 * Double(TRANSITION_TIME)
        navigationController?.navigationBarHidden = true
        sleepLengthPicker.delegate = self
        sleepLengthPicker.dataSource = self
        syncButton.enabled = activeSwitch.on

        loadStoredValues()

        var updateView = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: Selector("setViewStyle"), userInfo: nil, repeats: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        setViewStyle()
    }
    
    func setViewStyle() {
        let timeOfDay = getViewStyle()
        var (colors, image) = ViewSettings.getViewStyle(timeOfDay)

        currentBackgroundColor = colors["main"]
        tableView.backgroundColor = colors["main"]
        activeSwitchCell.backgroundColor = colors["cell"]
        wakeMeAtCell.backgroundColor = colors["cell"]
        wakeMeAtInfoCell.backgroundColor = colors["cell"]
        sleepLengthCell.backgroundColor = colors["cell"]
        sleepLengthInfoCell.backgroundColor = colors["cell"]
        syncButtonCell.backgroundColor = colors["cell"]
        owlImage.backgroundColor = tableView.backgroundColor
        owlImage.image = image
    }

    func getCurrentTime() -> NSDate {
        let calendar = NSCalendar.currentCalendar()
        let current = calendar.components(timeFlags, fromDate: NSDate())
        let dateString = "0001-01-01 \(current.hour):\(current.minute):00 +0000"
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"

        return dateFormatter.dateFromString(dateString)!
    }

    func getSleepTimes() -> (NSDate, NSDate) {
        let end = wakeMeAt.toUTCDate()
        let start = end.dateByAddingTimeInterval(Double(sleepLengthValue * -3600.0))

        return (start, end)
    }

    func getViewStyle() -> ViewStyle {
        var now = getCurrentTime()
        let (startOfNight, endOfNight) = getSleepTimes()

        if now.compare(endOfNight) == .OrderedDescending {
            now = now.dateByAddingTimeInterval(-3600*24)
        }

        if betweenDates(now, start: startOfNight, end: endOfNight) {
            return .Night
        }

        return .Day
    }

    func betweenDates(date: NSDate, start: NSDate, end: NSDate) -> Bool {
        return date.compare(start) != .OrderedAscending && date.compare(end) != .OrderedDescending
    }

    @IBAction func syncButtonTouchUp(sender: UIButton) {
        removeSchedules({ self.addSchedules() })
    }

    @IBAction func wakeMeAtPickerChanged(sender: AnyObject) {
        wakeMeAt = SleepTime.fromDate(wakeMeAtPicker.date)
        defaults.setObject(wakeMeAt.encode(), forKey: "WakeMeAt")
        wakeMeAtLabel.text = wakeMeAt.toString()
        setViewStyle()
    }

    func loadStoredValues() {
        // Active
        activeSwitch.on = defaults.boolForKey("active")
        syncButton.enabled = activeSwitch.on

        // Wake me at
        if let wakeMeAtEncoded: AnyObject = defaults.objectForKey("WakeMeAt") {
            wakeMeAt = SleepTime.decode(wakeMeAtEncoded as! [String : Int])
        } else {
            wakeMeAt = SleepTime(hour: 7, minute: 0)
        }
        wakeMeAtLabel.text = wakeMeAt.toString()
        wakeMeAtPicker.date = wakeMeAt.toDate()

        // Sleep length
        sleepLengthValue = defaults.floatForKey("sleepLengthValue")
        if sleepLengthValue == 0 {
            sleepLengthValue = 8.0
        }
        sleepLengthLabel.text = formatSleepLength(sleepLengthValue)
        setSelectedSleepLength()
    }

    func formatSleepLength(number: Float) -> String {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .DecimalStyle
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.stringFromNumber(NSNumber(float: number))! + " h"
    }

    func setSelectedSleepLength() {
        for row in 0...(sleepLengthData.count - 1) {
            if sleepLengthData[row] == sleepLengthValue {
                sleepLengthPicker.selectRow(row, inComponent: 0, animated: false)
                return
            }
        }
    }

    func toggleHiddenCell(cellIdentifier: String) {
        let i = find(hiddenCells, cellIdentifier)
        if i != nil {
            hiddenCells.removeAtIndex(i!)
        } else {
            hiddenCells.append(cellIdentifier)
        }
    }

    func triggerCellChangeAnimation() {
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    // UITableViewController Delegate
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)

        if cell.reuseIdentifier == "wakeMeAtInfoCell" {
            toggleHiddenCell("wakeMeAtPickerCell")
            triggerCellChangeAnimation()
        }
        if cell.reuseIdentifier == "sleepLengthInfoCell" {
            toggleHiddenCell("sleepLengthPickerCell")
            triggerCellChangeAnimation()
        }
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)

        if cell.reuseIdentifier != nil && contains(hiddenCells, cell.reuseIdentifier!) {
            return 0
        }

        return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
    }

    // Picker view data source
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return sleepLengthData.count
    }

    // Picker view delegate
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return formatSleepLength(sleepLengthData[row])
    }

    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        sleepLengthValue = sleepLengthData[row]
        defaults.setFloat(sleepLengthValue, forKey: "sleepLengthValue")
        sleepLengthLabel.text = formatSleepLength(sleepLengthValue)
        setViewStyle()
    }

    @IBAction func activeSwitchChanged(sender: AnyObject) {
        defaults.setBool(activeSwitch.on, forKey: "active")
        syncButton.enabled = activeSwitch.on
        if (activeSwitch.on) {
            addSchedules()
        } else {
            removeSchedules(nil)
        }
    }

    func addSchedules() {
        var (start, end) = getSleepTimes()

        scheduleSunset(start)
        scheduleSunrise(end)
    }

    func scheduleSunset(begin: NSDate) {
        schedule(ColorConfiguration.sunset(), date: begin)
    }

    func scheduleSunrise(begin: NSDate) {
        schedule(ColorConfiguration.sunrise(), date: begin)
    }

    func createSleepOnomicsSchedule(light: PHLight) -> PHSchedule {
        let newSchedule: PHSchedule = PHSchedule()
        newSchedule.name = SO_SCHEDULE_IDENTIFIER
        newSchedule.lightIdentifier = light.identifier
        newSchedule.recurringDays = RecurringAlldays
        newSchedule.localTime = true

        return newSchedule
    }

    func newTransitionSchedule(light: PHLight, transitionState: PHLightState?, date: NSDate) -> PHSchedule {
        let newSchedule = createSleepOnomicsSchedule(light)
        if transitionState != nil {
            newSchedule.state = transitionState
        }
        newSchedule.date = date.dateByAddingTimeInterval(transitionTime)

        return newSchedule
    }

    func newBrightnessSchedule(lightColor: LightSettings, light: PHLight, date: NSDate) -> PHSchedule {
        let brightnessTransition = PHLightState()
        brightnessTransition.brightness = lightColor.brightness
        brightnessTransition.transitionTime = TRANSITION_TIME
        let schedule = newTransitionSchedule(light, transitionState: brightnessTransition, date: date)

        return schedule
    }

    func newColourSchedule(lightColor: LightSettings, light: PHLight, date: NSDate) -> PHSchedule {
        let colourTransition = PHLightState()
        colourTransition.hue = lightColor.hue
        colourTransition.saturation = lightColor.saturation
        colourTransition.transitionTime = TRANSITION_TIME / 4
        let schedule = newTransitionSchedule(light, transitionState: colourTransition, date: date)

        return schedule
    }

    func schedule(lightSettings: LightSettings, date: NSDate) {
        let cache = PHBridgeResourcesReader.readBridgeResourcesCache()
        if cache.lights == nil {
            return
        }

        appDelegate.showLoadingViewWithText("Activate...")
        let bridgeSendAPI = PHBridgeSendAPI()

        var schedules: [PHSchedule] = []
        for object in cache.lights.values {
            let light = object as! PHLight

            let brightnessSchedule = newBrightnessSchedule(lightSettings, light: light, date: date)
            schedules.append(brightnessSchedule)

            let colourSchedule = newColourSchedule(lightSettings, light: light, date: date)
            schedules.append(colourSchedule)

            let switchState = PHLightState()
            switchState.on = !lightSettings.turnOff
            switchState.brightness = 1
            let switchSchedule = createSleepOnomicsSchedule(light)
            switchSchedule.state = switchState
            if lightSettings.turnOff {
                // State after transition
                switchSchedule.date = date
            } else {
                // Initial state
                // 10 seconds before transition starts, so that lamps start
                switchSchedule.date = date.dateByAddingTimeInterval(transitionTime - 10)
            }
            schedules.append(switchSchedule)
        }

        // Schedule
        if schedules.isEmpty {
            self.appDelegate.removeLoadingView()
        } else {
            var scheduleCounter = 0
            for schedule in schedules {
                bridgeSendAPI.createSchedule(schedule, completionHandler: { id, errorObjects in
                    self.handleApiErrors(errorObjects)
                    scheduleCounter++
                    if scheduleCounter == schedules.count {
                        self.appDelegate.removeLoadingView()
                    }
                })
            }
        }
    }

    func handleApiErrors(errorObjects: [AnyObject]?) {
        if errorObjects != nil {
            let errors = errorObjects as! [NSError]
            for error in errors {
                NSLog("%@", error)
            }
        }
    }

    func removeSchedules(completion: (() -> ())?) {
        appDelegate.showLoadingViewWithText("Deactivate...")
        let cache = PHBridgeResourcesReader.readBridgeResourcesCache()
        var schedulesToRemove: [String] = []

        if let schedules = cache.schedules as? [String: PHSchedule] {
            for (id, schedule) in schedules {
                if schedule.name == SO_SCHEDULE_IDENTIFIER {
                    schedulesToRemove.append(schedule.identifier)
                }
            }
        }

        if schedulesToRemove.isEmpty {
            self.appDelegate.removeLoadingView()
        } else {
            let bridgeSendAPI = PHBridgeSendAPI()
            var scheduleCounter = 0
            for scheduleId in schedulesToRemove {
                bridgeSendAPI.removeScheduleWithId(scheduleId, completionHandler: { errorObjects in
                    self.handleApiErrors(errorObjects)
                    scheduleCounter++
                    if scheduleCounter == schedulesToRemove.count {
                        self.appDelegate.removeLoadingView()
                        completion?()
                    }
                })
            }
        }
    }
}

