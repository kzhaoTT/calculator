import CCalcManager
import Foundation

@MainActor
public protocol UnitConverterBridgeDelegate: AnyObject {
    func onDisplayUpdated(from: String, to: String)
    func onSuggestedValuesUpdated(_ values: [SupplementaryResultItem])
    func onMaxDigitsReached()
}

/// Thin Swift wrapper around the unmodified C++ `UnitConversionManager::UnitConverter` via `CCalcManager`.
@MainActor
public final class UnitConverterBridge {
    private nonisolated(unsafe) var handle: CMUnitConverterRef?
    public weak var delegate: UnitConverterBridgeDelegate?

    public init(catalog: UnitConverterDataCatalog) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var callbacks = CMUnitConverterCallbacks()
        callbacks.context = context

        callbacks.onDisplay = { ctx, fromPtr, toPtr in
            guard let ctx else { return }
            let fromStr = fromPtr.map { String(cString: $0) } ?? "0"
            let toStr = toPtr.map { String(cString: $0) } ?? "0"
            MainActor.assumeIsolated {
                let bridge = Unmanaged<UnitConverterBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onDisplayUpdated(from: fromStr, to: toStr)
            }
        }

        callbacks.onSuggestedValues = { ctx, valsPtr, count in
            guard let ctx else { return }
            var items: [SupplementaryResultItem] = []
            if let valsPtr, count > 0 {
                items.reserveCapacity(count)
                for i in 0..<count {
                    let raw = valsPtr[i]
                    let valStr = raw.value.map { String(cString: $0) } ?? ""
                    let nameStr = raw.unitName.map { String(cString: $0) } ?? ""
                    let abbrStr = raw.unitAbbreviation.map { String(cString: $0) } ?? ""
                    items.append(SupplementaryResultItem(
                        id: raw.unitId,
                        value: valStr,
                        unitName: nameStr,
                        unitAbbreviation: abbrStr,
                        isWhimsical: raw.isWhimsical,
                        delighterEmoji: raw.isWhimsical ? UnitConverterDataCatalog.delighterEmojis[raw.unitId] : nil
                    ))
                }
            }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<UnitConverterBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onSuggestedValuesUpdated(items)
            }
        }

        callbacks.onMaxDigitsReached = { ctx in
            guard let ctx else { return }
            MainActor.assumeIsolated {
                let bridge = Unmanaged<UnitConverterBridge>.fromOpaque(ctx).takeUnretainedValue()
                bridge.delegate?.onMaxDigitsReached()
            }
        }

        self.handle = cm_uc_create(callbacks)
        loadCatalog(catalog)
    }

    deinit {
        if let handle {
            cm_uc_destroy(handle)
        }
    }

    public func loadCatalog(_ catalog: UnitConverterDataCatalog) {
        guard let handle else { return }
        cm_uc_begin_data(handle)
        for cat in catalog.categories {
            cat.name.withCString { namePtr in
                let def = CMCategoryDef(id: cat.id, name: namePtr, supportsNegative: cat.supportsNegative)
                cm_uc_add_category(handle, def, cat.isCurrency)
            }
            if let units = catalog.unitsByCategory[cat.id] {
                for u in units {
                    u.name.withCString { namePtr in
                        u.accessibleName.withCString { accPtr in
                            u.abbreviation.withCString { abbrPtr in
                                let def = CMUnitDef(
                                    id: u.id,
                                    name: namePtr,
                                    accessibleName: accPtr,
                                    abbreviation: abbrPtr,
                                    isSource: u.isSource,
                                    isTarget: u.isTarget,
                                    isWhimsical: u.isWhimsical
                                )
                                cm_uc_add_unit(handle, cat.id, def)
                            }
                        }
                    }
                }
            }
        }
        for r in catalog.ratios {
            let def = CMConversionRatioDef(
                fromUnitId: r.fromUnitId,
                toUnitId: r.toUnitId,
                ratio: r.ratio,
                offset: r.offset,
                offsetFirst: r.offsetFirst
            )
            cm_uc_add_ratio(handle, def)
        }
        cm_uc_finish_data(handle)
    }

    @discardableResult
    public func setCategory(_ categoryId: Int32) -> (fromUnitId: Int32, toUnitId: Int32) {
        var fromId: Int32 = -1
        var toId: Int32 = -1
        cm_uc_set_category(handle, categoryId, &fromId, &toId)
        return (fromId, toId)
    }

    public func setUnitTypes(fromUnitId: Int32, toUnitId: Int32) {
        cm_uc_set_unit_types(handle, fromUnitId, toUnitId)
    }

    public func switchActive(newValue: String) {
        newValue.withCString { ptr in
            cm_uc_switch_active(handle, ptr)
        }
    }

    public var isSwitchedActive: Bool {
        cm_uc_is_switched_active(handle)
    }

    public func sendCommand(_ command: UnitConverterCommand) {
        cm_uc_send_command(handle, command.rawValue)
    }

    public func calculate() {
        cm_uc_calculate(handle)
    }
}
