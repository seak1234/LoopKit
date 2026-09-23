//
//  HealthStoreUnitCache.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import os.log

public extension Notification.Name {
    // used to avoid potential timing issues since a unit change triggers a cache refresh and all stores pull the current unit from the cache
    static let HealthStorePreferredGlucoseUnitDidChange = Notification.Name(rawValue:  "com.loopKit.notification.HealthStorePreferredGlucoseUnitDidChange")
}

public class HealthStoreUnitCache {
    private static var cacheCache = NSMapTable<HKHealthStore, HealthStoreUnitCache>.weakToStrongObjects()
    private static var cacheCacheLock = UnfairLock()

    public let healthStore: HKHealthStore

    private static let fixedUnits: [HKQuantityTypeIdentifier: HKUnit] = [
        .dietaryCarbohydrates: .gram(),
        .insulinDelivery: .internationalUnit()
    ]

    private var unitCache = Locked([HKQuantityTypeIdentifier: HKUnit]())

    private var userPreferencesChangeObserver: Any?

    private init(healthStore: HKHealthStore) {
        self.healthStore = healthStore

        userPreferencesChangeObserver = NotificationCenter.default.addObserver(forName: .HKUserPreferencesDidChange, object: healthStore, queue: nil, using: { [weak self] _ in
            DispatchQueue.global().async {
                self?.updateCachedUnits()
            }
        })
    }

    public class func unitCache(for healthStore: HKHealthStore) -> HealthStoreUnitCache {
        cacheCacheLock.withLock {
            if let cache = cacheCache.object(forKey: healthStore) {
                return cache
            }

            let cache = HealthStoreUnitCache(healthStore: healthStore)
            cacheCache.setObject(cache, forKey: healthStore)
            return cache
        }
    }

    public static let userPreferredGlucoseUnitKey = "UserPreferredGlucoseUnit"

    public static var appGroupSuiteName: String? {
        didSet {
            if let suiteName = appGroupSuiteName {
                appGroupUserDefaults = UserDefaults(suiteName: suiteName)
            } else {
                appGroupUserDefaults = nil
            }
        }
    }

    private static var appGroupUserDefaults: UserDefaults?

    public static var userPreferredGlucoseUnit: HKUnit? {
        get {
            guard let string = userPreferredGlucoseUnitString else { return nil }
            if string == "mmol/L" || string == HKUnit.millimolesPerLiter.unitString {
                return .millimolesPerLiter
            } else if string == "mg/dL" || string == HKUnit.milligramsPerDeciliter.unitString {
                return .milligramsPerDeciliter
            }
            return nil
        }
        set {
            userPreferredGlucoseUnitString = newValue?.unitString
        }
    }

    public static var userPreferredGlucoseUnitString: String? {
        get {
            return (appGroupUserDefaults ?? UserDefaults.standard).string(forKey: userPreferredGlucoseUnitKey) ?? UserDefaults.standard.string(forKey: userPreferredGlucoseUnitKey)
        }
        set {
            if let newValue = newValue {
                appGroupUserDefaults?.set(newValue, forKey: userPreferredGlucoseUnitKey)
                UserDefaults.standard.set(newValue, forKey: userPreferredGlucoseUnitKey)
            } else {
                appGroupUserDefaults?.removeObject(forKey: userPreferredGlucoseUnitKey)
                UserDefaults.standard.removeObject(forKey: userPreferredGlucoseUnitKey)
            }
        }
    }

    public func setUserPreferredUnit(_ unit: HKUnit, for quantityTypeIdentifier: HKQuantityTypeIdentifier) {
        if quantityTypeIdentifier == .bloodGlucose {
            HealthStoreUnitCache.userPreferredGlucoseUnit = unit
        }
        updateCache(for: quantityTypeIdentifier, with: unit)
    }

    public func preferredUnit(for quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKUnit? {
        if quantityTypeIdentifier == .bloodGlucose,
           let userUnit = HealthStoreUnitCache.userPreferredGlucoseUnit
        {
            if unitCache.value[quantityTypeIdentifier] != userUnit {
                _ = unitCache.mutate { $0[quantityTypeIdentifier] = userUnit }
            }
            return userUnit
        }

        if let unit = HealthStoreUnitCache.fixedUnits[quantityTypeIdentifier] {
            return unit
        }

        if let unit = unitCache.value[quantityTypeIdentifier] {
            return unit
        }

        return getHealthStoreUnitAndUpdateCache(for: quantityTypeIdentifier)
    }

    @discardableResult private func getHealthStoreUnitAndUpdateCache(for quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKUnit? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: quantityTypeIdentifier) else {
            return nil
        }

        var unit: HKUnit?
        let semaphore = DispatchSemaphore(value: 0)

        healthStore.preferredUnits(for: [quantityType]) { (results, error) in
            if let error = error {
                // This is a common/expected case when protected data is unavailable
                OSLog(category: "HealthStoreUnitCache").info("Error fetching unit for %{public}@: %{public}@", quantityTypeIdentifier.rawValue, String(describing: error))
            }

            unit = results[quantityType]

            self.updateCache(for: quantityTypeIdentifier, with: unit)

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return unit
    }

    private func updateCachedUnits() {
        let quantityTypeIdentifiers = unitCache.value.keys
        for quantityTypeIdentifier in quantityTypeIdentifiers {
            self.getHealthStoreUnitAndUpdateCache(for: quantityTypeIdentifier)
        }
    }

    private func updateCache(for quantityTypeIdentifier: HKQuantityTypeIdentifier, with unit: HKUnit?) {
        _ = self.unitCache.mutate({ (cache) in
            guard unit != cache[quantityTypeIdentifier] else {
                return
            }

            cache[quantityTypeIdentifier] = unit
            switch quantityTypeIdentifier {
            case .bloodGlucose:
                // currently only changes to glucose unit is reported
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .HealthStorePreferredGlucoseUnitDidChange, object: self.healthStore)
                }
            default:
                break
            }
        })
    }

    deinit {
        if let observer = userPreferencesChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

