#include "CCalcManager.h"

#include "CalculatorManager.h"
#include "CalculatorResource.h"
#include "Command.h"
#include "ExpressionCommand.h"
#include "UnitConverter.h"

#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace {

// UTF-8 <-> std::wstring (UTF-32 on macOS / Apple platforms) conversion helpers.
std::string wstringToUtf8(std::wstring_view ws)
{
    std::string out;
    out.reserve(ws.size() * 2);
    for (wchar_t wc : ws)
    {
        uint32_t cp = static_cast<uint32_t>(wc);
        if (cp <= 0x7F)
        {
            out.push_back(static_cast<char>(cp));
        }
        else if (cp <= 0x7FF)
        {
            out.push_back(static_cast<char>(0xC0 | ((cp >> 6) & 0x1F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
        else if (cp <= 0xFFFF)
        {
            out.push_back(static_cast<char>(0xE0 | ((cp >> 12) & 0x0F)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
        else if (cp <= 0x10FFFF)
        {
            out.push_back(static_cast<char>(0xF0 | ((cp >> 18) & 0x07)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }
    return out;
}

std::wstring utf8ToWstring(const char* s)
{
    if (!s) return {};
    std::wstring out;
    const unsigned char* p = reinterpret_cast<const unsigned char*>(s);
    while (*p)
    {
        uint32_t cp = 0;
        if (*p < 0x80)
        {
            cp = *p++;
        }
        else if ((*p & 0xE0) == 0xC0 && p[1])
        {
            cp = ((*p & 0x1F) << 6) | (p[1] & 0x3F);
            p += 2;
        }
        else if ((*p & 0xF0) == 0xE0 && p[1] && p[2])
        {
            cp = ((*p & 0x0F) << 12) | ((p[1] & 0x3F) << 6) | (p[2] & 0x3F);
            p += 3;
        }
        else if ((*p & 0xF8) == 0xF0 && p[1] && p[2] && p[3])
        {
            cp = ((*p & 0x07) << 18) | ((p[1] & 0x3F) << 12) | ((p[2] & 0x3F) << 6) | (p[3] & 0x3F);
            p += 4;
        }
        else
        {
            cp = *p++;
        }
        out.push_back(static_cast<wchar_t>(cp));
    }
    return out;
}

char* dupCString(const std::string& s)
{
    char* copy = static_cast<char*>(std::malloc(s.size() + 1));
    if (copy)
    {
        std::memcpy(copy, s.c_str(), s.size() + 1);
    }
    return copy;
}

std::vector<int> extractCommandsFromExpression(
    const std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>>& expressionCommands)
{
    std::vector<int> commands;
    if (!expressionCommands) return commands;

    for (const auto& command : *expressionCommands)
    {
        if (!command) continue;
        switch (command->GetCommandType())
        {
        case CalculationManager::CommandType::UnaryCommand:
        {
            auto unary = std::dynamic_pointer_cast<IUnaryCommand>(command);
            if (unary && unary->GetCommands())
            {
                for (int code : *unary->GetCommands())
                {
                    commands.push_back(code);
                }
            }
            break;
        }
        case CalculationManager::CommandType::BinaryCommand:
        {
            auto binary = std::dynamic_pointer_cast<IBinaryCommand>(command);
            if (binary)
            {
                commands.push_back(binary->GetCommand());
            }
            break;
        }
        case CalculationManager::CommandType::Parentheses:
        {
            auto paren = std::dynamic_pointer_cast<IParenthesisCommand>(command);
            if (paren)
            {
                commands.push_back(paren->GetCommand());
            }
            break;
        }
        case CalculationManager::CommandType::OperandCommand:
        {
            auto opnd = std::dynamic_pointer_cast<IOpndCommand>(command);
            if (opnd && opnd->GetCommands())
            {
                bool needSign = opnd->IsNegative();
                for (int code : *opnd->GetCommands())
                {
                    commands.push_back(code);
                    if (needSign && code != static_cast<int>(CalculationManager::Command::Command0))
                    {
                        commands.push_back(static_cast<int>(CalculationManager::Command::CommandSIGN));
                        needSign = false;
                    }
                }
            }
            break;
        }
        }
    }
    return commands;
}

class BridgeResourceProvider final : public CalculationManager::IResourceProvider
{
public:
    explicit BridgeResourceProvider(CMCalculatorCallbacks cb) : m_cb(cb) {}

    std::wstring GetCEngineString(std::wstring_view id) override
    {
        if (!m_cb.getEngineString) return {};
        std::string utf8Id = wstringToUtf8(id);
        char buf[1024];
        size_t len = m_cb.getEngineString(m_cb.context, utf8Id.c_str(), buf, sizeof(buf));
        if (len >= sizeof(buf))
        {
            std::vector<char> big(len + 1);
            len = m_cb.getEngineString(m_cb.context, utf8Id.c_str(), big.data(), big.size());
            big[len] = '\0';
            return utf8ToWstring(big.data());
        }
        buf[len] = '\0';
        return utf8ToWstring(buf);
    }

private:
    CMCalculatorCallbacks m_cb;
};

class BridgeCalcDisplay final : public ICalcDisplay
{
public:
    explicit BridgeCalcDisplay(CMCalculatorCallbacks cb) : m_cb(cb) {}

    void SetPrimaryDisplay(const std::wstring& pszText, bool isError) override
    {
        if (m_cb.onPrimaryDisplay)
        {
            std::string utf8 = wstringToUtf8(pszText);
            m_cb.onPrimaryDisplay(m_cb.context, utf8.c_str(), isError);
        }
    }

    void SetIsInError(bool isInError) override
    {
        if (m_cb.onIsInError)
        {
            m_cb.onIsInError(m_cb.context, isInError);
        }
    }

    void SetExpressionDisplay(
        _Inout_ std::shared_ptr<std::vector<std::pair<std::wstring, int>>> const& tokens,
        _Inout_ std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>> const& commands) override
    {
        if (!m_cb.onExpressionDisplay) return;
        std::vector<std::string> storage;
        std::vector<CMToken> outTokens;
        if (tokens)
        {
            storage.reserve(tokens->size());
            outTokens.reserve(tokens->size());
            for (const auto& tok : *tokens)
            {
                storage.push_back(wstringToUtf8(tok.first));
                CMTokenType type = CMTokenTypeOperator;
                if (tok.second == -1)
                {
                    type = (tok.first == L" ") ? CMTokenTypeSeparator : CMTokenTypeOperator;
                }
                else if (commands && static_cast<size_t>(tok.second) < commands->size() && (*commands)[tok.second])
                {
                    type = ((*commands)[tok.second]->GetCommandType() == CalculationManager::CommandType::OperandCommand)
                        ? CMTokenTypeOperand
                        : CMTokenTypeOperator;
                }
                outTokens.push_back(CMToken{ storage.back().c_str(), tok.second, type });
            }
        }
        m_cb.onExpressionDisplay(m_cb.context, outTokens.data(), outTokens.size());
    }

    void SetParenthesisNumber(_In_ unsigned int count) override
    {
        if (m_cb.onParenthesisCount)
        {
            m_cb.onParenthesisCount(m_cb.context, count);
        }
    }

    void OnNoRightParenAdded() override
    {
        if (m_cb.onNoRightParenAdded)
        {
            m_cb.onNoRightParenAdded(m_cb.context);
        }
    }

    void MaxDigitsReached() override
    {
        if (m_cb.onMaxDigitsReached)
        {
            m_cb.onMaxDigitsReached(m_cb.context);
        }
    }

    void BinaryOperatorReceived() override
    {
        if (m_cb.onBinaryOperatorReceived)
        {
            m_cb.onBinaryOperatorReceived(m_cb.context);
        }
    }

    void OnHistoryItemAdded(_In_ unsigned int addedItemIndex) override
    {
        if (m_cb.onHistoryItemAdded)
        {
            m_cb.onHistoryItemAdded(m_cb.context, addedItemIndex);
        }
    }

    void SetMemorizedNumbers(const std::vector<std::wstring>& memorizedNumbers) override
    {
        if (!m_cb.onMemorizedNumbers) return;
        std::vector<std::string> storage;
        std::vector<const char*> ptrs;
        storage.reserve(memorizedNumbers.size());
        ptrs.reserve(memorizedNumbers.size());
        for (const auto& s : memorizedNumbers)
        {
            storage.push_back(wstringToUtf8(s));
            ptrs.push_back(storage.back().c_str());
        }
        m_cb.onMemorizedNumbers(m_cb.context, ptrs.data(), ptrs.size());
    }

    void MemoryItemChanged(unsigned int indexOfMemory) override
    {
        if (m_cb.onMemoryItemChanged)
        {
            m_cb.onMemoryItemChanged(m_cb.context, indexOfMemory);
        }
    }

    void InputChanged() override
    {
        if (m_cb.onInputChanged)
        {
            m_cb.onInputChanged(m_cb.context);
        }
    }

private:
    CMCalculatorCallbacks m_cb;
};

// MARK: - UnitConverter Bridge Classes

class BridgeUnitDataLoader final : public UnitConversionManager::IConverterDataLoader
{
public:
    void Clear()
    {
        m_categories.clear();
        m_unitsByCategory.clear();
        m_unitsById.clear();
        m_ratiosByUnitId.clear();
        m_currencyCategoryIds.clear();
    }

    void AddCategory(const CMCategoryDef& cat, bool isCurrency)
    {
        UnitConversionManager::Category c(cat.id, utf8ToWstring(cat.name), cat.supportsNegative);
        m_categories.push_back(std::move(c));
        if (isCurrency)
        {
            m_currencyCategoryIds.insert(cat.id);
        }
    }

    void AddUnit(int32_t categoryId, const CMUnitDef& u)
    {
        UnitConversionManager::Unit unit(
            u.id,
            utf8ToWstring(u.name),
            utf8ToWstring(u.abbreviation),
            u.isSource,
            u.isTarget,
            u.isWhimsical);
        unit.accessibleName = utf8ToWstring(u.accessibleName);
        m_unitsByCategory[categoryId].push_back(unit);
        m_unitsById[u.id] = unit;
    }

    void AddRatio(const CMConversionRatioDef& r)
    {
        auto it = m_unitsById.find(r.toUnitId);
        if (it == m_unitsById.end()) return;
        m_ratiosByUnitId[r.fromUnitId][it->second] =
            UnitConversionManager::ConversionData(r.ratio, r.offset, r.offsetFirst);
    }

    const UnitConversionManager::Category* FindCategory(int32_t id) const
    {
        for (const auto& c : m_categories)
        {
            if (c.id == id) return &c;
        }
        return nullptr;
    }

    const UnitConversionManager::Unit* FindUnit(int32_t id) const
    {
        auto it = m_unitsById.find(id);
        return it == m_unitsById.end() ? nullptr : &it->second;
    }

    bool IsCurrencyCategory(int32_t id) const
    {
        return m_currencyCategoryIds.count(id) > 0;
    }

    // IConverterDataLoader
    void LoadData() override {}

    std::vector<UnitConversionManager::Category> GetOrderedCategories() override
    {
        return m_categories;
    }

    std::vector<UnitConversionManager::Unit> GetOrderedUnits(const UnitConversionManager::Category& c) override
    {
        auto it = m_unitsByCategory.find(c.id);
        if (it != m_unitsByCategory.end()) return it->second;
        return {};
    }

    std::unordered_map<UnitConversionManager::Unit, UnitConversionManager::ConversionData, UnitConversionManager::UnitHash>
    LoadOrderedRatios(const UnitConversionManager::Unit& u) override
    {
        auto it = m_ratiosByUnitId.find(u.id);
        if (it != m_ratiosByUnitId.end()) return it->second;
        return {};
    }

    bool SupportsCategory(const UnitConversionManager::Category& target) override
    {
        return m_currencyCategoryIds.count(target.id) == 0;
    }

private:
    std::vector<UnitConversionManager::Category> m_categories;
    std::unordered_map<int32_t, std::vector<UnitConversionManager::Unit>> m_unitsByCategory;
    std::unordered_map<int32_t, UnitConversionManager::Unit> m_unitsById;
    std::unordered_map<
        int32_t,
        std::unordered_map<UnitConversionManager::Unit, UnitConversionManager::ConversionData, UnitConversionManager::UnitHash>>
        m_ratiosByUnitId;
    std::unordered_set<int32_t> m_currencyCategoryIds;
};

class BridgeCurrencyDataLoader final : public UnitConversionManager::IConverterDataLoader
{
public:
    explicit BridgeCurrencyDataLoader(std::shared_ptr<BridgeUnitDataLoader> shared)
        : m_shared(std::move(shared)) {}

    void LoadData() override {}

    std::vector<UnitConversionManager::Category> GetOrderedCategories() override
    {
        return m_shared->GetOrderedCategories();
    }

    std::vector<UnitConversionManager::Unit> GetOrderedUnits(const UnitConversionManager::Category& c) override
    {
        return m_shared->GetOrderedUnits(c);
    }

    std::unordered_map<UnitConversionManager::Unit, UnitConversionManager::ConversionData, UnitConversionManager::UnitHash>
    LoadOrderedRatios(const UnitConversionManager::Unit& u) override
    {
        return m_shared->LoadOrderedRatios(u);
    }

    bool SupportsCategory(const UnitConversionManager::Category& target) override
    {
        return m_shared->IsCurrencyCategory(target.id);
    }

private:
    std::shared_ptr<BridgeUnitDataLoader> m_shared;
};

class BridgeUnitConverterCallback final : public UnitConversionManager::IUnitConverterVMCallback
{
public:
    explicit BridgeUnitConverterCallback(CMUnitConverterCallbacks cb) : m_cb(cb) {}

    void DisplayCallback(const std::wstring& from, const std::wstring& to) override
    {
        if (!m_cb.onDisplay) return;
        std::string f = wstringToUtf8(from);
        std::string t = wstringToUtf8(to);
        m_cb.onDisplay(m_cb.context, f.c_str(), t.c_str());
    }

    void SuggestedValueCallback(const std::vector<std::tuple<std::wstring, UnitConversionManager::Unit>>& suggestedValues) override
    {
        if (!m_cb.onSuggestedValues) return;
        std::vector<std::string> storage;
        storage.reserve(suggestedValues.size() * 3);
        std::vector<CMSuggestedValue> out;
        out.reserve(suggestedValues.size());
        for (const auto& item : suggestedValues)
        {
            const auto& valStr = std::get<0>(item);
            const auto& unit = std::get<1>(item);
            storage.push_back(wstringToUtf8(valStr));
            const char* valPtr = storage.back().c_str();
            storage.push_back(wstringToUtf8(unit.name));
            const char* namePtr = storage.back().c_str();
            storage.push_back(wstringToUtf8(unit.abbreviation));
            const char* abbrPtr = storage.back().c_str();
            out.push_back(CMSuggestedValue{ valPtr, unit.id, namePtr, abbrPtr, unit.isWhimsical });
        }
        m_cb.onSuggestedValues(m_cb.context, out.data(), out.size());
    }

    void MaxDigitsReached() override
    {
        if (m_cb.onMaxDigitsReached)
        {
            m_cb.onMaxDigitsReached(m_cb.context);
        }
    }

private:
    CMUnitConverterCallbacks m_cb;
};

} // namespace

struct CMCalculatorOpaque
{
    std::unique_ptr<BridgeCalcDisplay> display;
    std::unique_ptr<BridgeResourceProvider> resourceProvider;
    std::unique_ptr<CalculationManager::CalculatorManager> manager;
};

struct CMUnitConverterOpaque
{
    std::shared_ptr<BridgeUnitDataLoader> dataLoader;
    std::shared_ptr<BridgeCurrencyDataLoader> currencyLoader;
    std::shared_ptr<BridgeUnitConverterCallback> callback;
    std::shared_ptr<UnitConversionManager::UnitConverter> converter;
};

extern "C" {

void cm_string_free(char* str)
{
    std::free(str);
}

// MARK: - CalculatorManager C API

CMCalculatorRef cm_calc_create(CMCalculatorCallbacks callbacks)
{
    auto* wrapper = new CMCalculatorOpaque();
    wrapper->display = std::make_unique<BridgeCalcDisplay>(callbacks);
    wrapper->resourceProvider = std::make_unique<BridgeResourceProvider>(callbacks);
    wrapper->manager = std::make_unique<CalculationManager::CalculatorManager>(
        wrapper->display.get(),
        wrapper->resourceProvider.get());
    wrapper->manager->SetStandardMode();
    return wrapper;
}

void cm_calc_destroy(CMCalculatorRef ref)
{
    delete ref;
}

void cm_calc_reset(CMCalculatorRef ref, bool clearMemory)
{
    if (ref && ref->manager) ref->manager->Reset(clearMemory);
}

void cm_calc_set_standard_mode(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->SetStandardMode();
}

void cm_calc_set_scientific_mode(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->SetScientificMode();
}

void cm_calc_set_programmer_mode(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->SetProgrammerMode();
}

void cm_calc_send_command(CMCalculatorRef ref, int32_t command)
{
    if (ref && ref->manager)
    {
        ref->manager->SendCommand(static_cast<CalculationManager::Command>(command));
    }
}

void cm_calc_set_radix(CMCalculatorRef ref, int32_t radixType)
{
    if (ref && ref->manager)
    {
        ref->manager->SetRadix(static_cast<RadixType>(radixType));
    }
}

void cm_calc_set_precision(CMCalculatorRef ref, int32_t precision)
{
    if (ref && ref->manager)
    {
        ref->manager->SetPrecision(precision);
    }
}

void cm_calc_update_max_int_digits(CMCalculatorRef ref)
{
    if (ref && ref->manager)
    {
        ref->manager->UpdateMaxIntDigits();
    }
}

char* cm_calc_get_result_for_radix(CMCalculatorRef ref, uint32_t radix, int32_t precision, bool groupDigits)
{
    if (!ref || !ref->manager) return dupCString("");
    std::wstring res = ref->manager->GetResultForRadix(radix, precision, groupDigits);
    return dupCString(wstringToUtf8(res));
}

bool cm_calc_is_input_empty(CMCalculatorRef ref)
{
    if (!ref || !ref->manager) return true;
    return ref->manager->IsInputEmpty();
}

int32_t cm_calc_get_current_degree_mode(CMCalculatorRef ref)
{
    if (!ref || !ref->manager) return static_cast<int32_t>(CalculationManager::Command::CommandDEG);
    return static_cast<int32_t>(ref->manager->GetCurrentDegreeMode());
}

void cm_calc_memorize_number(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->MemorizeNumber();
}

void cm_calc_memorized_load(CMCalculatorRef ref, uint32_t idx)
{
    if (ref && ref->manager) ref->manager->MemorizedNumberLoad(idx);
}

void cm_calc_memorized_add(CMCalculatorRef ref, uint32_t idx)
{
    if (ref && ref->manager) ref->manager->MemorizedNumberAdd(idx);
}

void cm_calc_memorized_subtract(CMCalculatorRef ref, uint32_t idx)
{
    if (ref && ref->manager) ref->manager->MemorizedNumberSubtract(idx);
}

void cm_calc_memorized_clear(CMCalculatorRef ref, uint32_t idx)
{
    if (ref && ref->manager) ref->manager->MemorizedNumberClear(idx);
}

void cm_calc_memorized_clear_all(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->MemorizedNumberClearAll();
}

void cm_calc_set_memorized_numbers_string(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->SetMemorizedNumbersString();
}

size_t cm_calc_history_count(CMCalculatorRef ref)
{
    if (!ref || !ref->manager) return 0;
    return ref->manager->GetHistoryItems().size();
}

size_t cm_calc_history_count_for_mode(CMCalculatorRef ref, int32_t mode)
{
    if (!ref || !ref->manager) return 0;
    auto calcMode = (mode == 1) ? CalculationManager::CalculatorMode::Scientific : CalculationManager::CalculatorMode::Standard;
    return ref->manager->GetHistoryItems(calcMode).size();
}

size_t cm_calc_history_max_size(CMCalculatorRef ref)
{
    if (!ref || !ref->manager) return 0;
    return ref->manager->MaxHistorySize();
}

bool cm_calc_history_get(CMCalculatorRef ref, uint32_t idx, char** outExpression, char** outResult)
{
    if (!ref || !ref->manager) return false;
    const auto& items = ref->manager->GetHistoryItems();
    if (idx >= items.size() || !items[idx]) return false;
    if (outExpression) *outExpression = dupCString(wstringToUtf8(items[idx]->historyItemVector.expression));
    if (outResult) *outResult = dupCString(wstringToUtf8(items[idx]->historyItemVector.result));
    return true;
}

bool cm_calc_history_get_for_mode(CMCalculatorRef ref, int32_t mode, uint32_t idx, char** outExpression, char** outResult)
{
    if (!ref || !ref->manager) return false;
    auto calcMode = (mode == 1) ? CalculationManager::CalculatorMode::Scientific : CalculationManager::CalculatorMode::Standard;
    const auto& items = ref->manager->GetHistoryItems(calcMode);
    if (idx >= items.size() || !items[idx]) return false;
    if (outExpression) *outExpression = dupCString(wstringToUtf8(items[idx]->historyItemVector.expression));
    if (outResult) *outResult = dupCString(wstringToUtf8(items[idx]->historyItemVector.result));
    return true;
}

bool cm_calc_history_load(CMCalculatorRef ref, uint32_t idx, bool isScientific, bool isFToE)
{
    if (!ref || !ref->manager) return false;
    const auto& items = ref->manager->GetHistoryItems();
    if (idx >= items.size() || !items[idx]) return false;

    auto item = items[idx];
    auto tokens = item->historyItemVector.spTokens;
    auto commands = item->historyItemVector.spCommands;
    std::wstring savedResult = item->historyItemVector.result;

    auto replayCmds = extractCommandsFromExpression(commands);
    auto currentDegreeMode = ref->manager->GetCurrentDegreeMode();

    ref->manager->SetInHistoryItemLoadMode(true);
    ref->manager->Reset(false);
    if (isScientific)
    {
        ref->manager->SendCommand(CalculationManager::Command::ModeScientific);
    }
    if (isFToE)
    {
        ref->manager->SendCommand(CalculationManager::Command::CommandFE);
    }
    if (currentDegreeMode != CalculationManager::Command::CommandNULL)
    {
        ref->manager->SendCommand(currentDegreeMode);
    }
    for (int cmd : replayCmds)
    {
        ref->manager->SendCommand(static_cast<CalculationManager::Command>(cmd));
    }
    ref->manager->SendCommand(CalculationManager::Command::CommandFE);
    ref->manager->SendCommand(CalculationManager::Command::CommandFE);
    ref->manager->SetInHistoryItemLoadMode(false);

    if (ref->display)
    {
        ref->display->SetExpressionDisplay(tokens, commands);
        ref->display->SetPrimaryDisplay(savedResult, false);
    }
    return true;
}

bool cm_calc_history_remove(CMCalculatorRef ref, uint32_t idx)
{
    if (!ref || !ref->manager) return false;
    return ref->manager->RemoveHistoryItem(idx);
}

void cm_calc_history_clear(CMCalculatorRef ref)
{
    if (ref && ref->manager) ref->manager->ClearHistory();
}

// MARK: - UnitConverter C API

CMUnitConverterRef cm_uc_create(CMUnitConverterCallbacks callbacks)
{
    auto* wrapper = new CMUnitConverterOpaque();
    wrapper->dataLoader = std::make_shared<BridgeUnitDataLoader>();
    wrapper->currencyLoader = std::make_shared<BridgeCurrencyDataLoader>(wrapper->dataLoader);
    wrapper->callback = std::make_shared<BridgeUnitConverterCallback>(callbacks);
    wrapper->converter = std::make_shared<UnitConversionManager::UnitConverter>(
        wrapper->dataLoader,
        wrapper->currencyLoader);
    wrapper->converter->SetViewModelCallback(wrapper->callback);
    return wrapper;
}

void cm_uc_destroy(CMUnitConverterRef ref)
{
    delete ref;
}

void cm_uc_begin_data(CMUnitConverterRef ref)
{
    if (ref && ref->dataLoader)
    {
        ref->dataLoader->Clear();
    }
}

void cm_uc_add_category(CMUnitConverterRef ref, CMCategoryDef category, bool isCurrency)
{
    if (ref && ref->dataLoader)
    {
        ref->dataLoader->AddCategory(category, isCurrency);
    }
}

void cm_uc_add_unit(CMUnitConverterRef ref, int32_t categoryId, CMUnitDef unit)
{
    if (ref && ref->dataLoader)
    {
        ref->dataLoader->AddUnit(categoryId, unit);
    }
}

void cm_uc_add_ratio(CMUnitConverterRef ref, CMConversionRatioDef ratio)
{
    if (ref && ref->dataLoader)
    {
        ref->dataLoader->AddRatio(ratio);
    }
}

void cm_uc_finish_data(CMUnitConverterRef ref)
{
    if (ref && ref->converter)
    {
        ref->converter->ResetCategoriesAndRatios();
    }
}

void cm_uc_set_category(CMUnitConverterRef ref, int32_t categoryId, int32_t* outFromUnitId, int32_t* outToUnitId)
{
    if (!ref || !ref->converter || !ref->dataLoader) return;
    const auto* cat = ref->dataLoader->FindCategory(categoryId);
    if (!cat) return;
    auto init = ref->converter->SetCurrentCategory(*cat);
    if (outFromUnitId) *outFromUnitId = std::get<1>(init).id;
    if (outToUnitId) *outToUnitId = std::get<2>(init).id;
}

void cm_uc_set_unit_types(CMUnitConverterRef ref, int32_t fromUnitId, int32_t toUnitId)
{
    if (!ref || !ref->converter || !ref->dataLoader) return;
    const auto* fromU = ref->dataLoader->FindUnit(fromUnitId);
    const auto* toU = ref->dataLoader->FindUnit(toUnitId);
    if (fromU && toU)
    {
        ref->converter->SetCurrentUnitTypes(*fromU, *toU);
    }
}

void cm_uc_switch_active(CMUnitConverterRef ref, const char* newValue)
{
    if (!ref || !ref->converter) return;
    ref->converter->SwitchActive(utf8ToWstring(newValue));
}

bool cm_uc_is_switched_active(CMUnitConverterRef ref)
{
    if (!ref || !ref->converter) return false;
    return ref->converter->IsSwitchedActive();
}

void cm_uc_send_command(CMUnitConverterRef ref, int32_t command)
{
    if (!ref || !ref->converter) return;
    ref->converter->SendCommand(static_cast<UnitConversionManager::Command>(command));
}

void cm_uc_calculate(CMUnitConverterRef ref)
{
    if (!ref || !ref->converter) return;
    ref->converter->Calculate();
}

} // extern "C"
