//
//  CallbackRepeater.swift
//  jsn
//
//  Created by Jorrit van Asselt on 24/12/2022.
//

import Foundation

/// Schedules retrieving an update every specified minutes
class CallbackRepeater
{
    private let activeTimeStart: DateComponents?
    private let activeTimeEnd: DateComponents?
    private let callback: ( () -> Void)
    private var timer: Timer? = nil
    let interval: TimeInterval
    
    /// After initizialization, the
    init(interval inSeconds: TimeInterval,
         activeTimeStart: DateComponents? = nil,
         activeTimeEnd: DateComponents? = nil,
         callback: @escaping ( () -> Void))
    {
        self.interval = inSeconds
        self.activeTimeStart = activeTimeStart
        self.activeTimeEnd = activeTimeEnd
        self.callback = callback
        start()
    }
    
    private func start()
    {
        let timer = Timer(fire: Date.now,
                          interval: interval,
                          repeats: true)
        {
            self.timerFired(timer: $0)
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }
    
    private func timerFired(timer: Timer)
    {
        if let startOfActiveTime = activeTimeStart,
           let endOfActiveTime = activeTimeEnd
        {
            
            let now = Date()
            let calendar = NSLocale.current.calendar
            let nowComponents = calendar.dateComponents([.year,
                                                         .month,
                                                         .day,
                                                         .minute,
                                                         .hour],
                                                        from: now)
            
            let startActiveComponents = DateComponents(year: nowComponents.year,
                                                       month: nowComponents.month,
                                                       day: nowComponents.day,
                                                       hour: startOfActiveTime.hour,
                                                       minute: startOfActiveTime.minute)
            let endActiveComponents = DateComponents(year: nowComponents.year,
                                                     month: nowComponents.month,
                                                     day: nowComponents.day,
                                                     hour: endOfActiveTime.hour,
                                                     minute: endOfActiveTime.minute)
            
            guard let startActiveTime = calendar.date(from: startActiveComponents),
                  let endActiveTime = calendar.date(from: endActiveComponents)
            else { fatalError("Could not create start or end date") }
            
            if now > startActiveTime &&
                now < endActiveTime
            { callback() }
        }
        else
        {
            callback()
        }
    }
}
