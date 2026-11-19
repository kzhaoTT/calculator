#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - String memory management

void cm_string_free(char* str);

// MARK: - CalculatorManager C Bridge

typedef struct CMCalculatorOpaque* CMCalculatorRef;

typedef enum {
    CMTokenTypeOperand = 0,
    CMTokenTypeOperator = 1,
    CMTokenTypeSeparator = 2
} CMTokenType;

typedef struct {
    const char* value;
    int32_t commandIndex;
    CMTokenType tokenType;
} CMToken;

typedef struct {
    void* context;
    void (*onPrimaryDisplay)(void* ctx, const char* display, bool isError);
    void (*onIsInError)(void* ctx, bool isError);
    void (*onExpressionDisplay)(void* ctx, const CMToken* tokens, size_t count);
    void (*onParenthesisCount)(void* ctx, uint32_t count);
    void (*onNoRightParenAdded)(void* ctx);
    void (*onMaxDigitsReached)(void* ctx);
    void (*onBinaryOperatorReceived)(void* ctx);
    void (*onHistoryItemAdded)(void* ctx, uint32_t addedItemIndex);
    void (*onMemorizedNumbers)(void* ctx, const char* const* items, size_t count);
    void (*onMemoryItemChanged)(void* ctx, uint32_t index);
    void (*onInputChanged)(void* ctx);
    size_t (*getEngineString)(void* ctx, const char* id, char* outBuffer, size_t outBufferSize);
} CMCalculatorCallbacks;

CMCalculatorRef cm_calc_create(CMCalculatorCallbacks callbacks);
void cm_calc_destroy(CMCalculatorRef ref);

void cm_calc_reset(CMCalculatorRef ref, bool clearMemory);
void cm_calc_set_standard_mode(CMCalculatorRef ref);
void cm_calc_set_scientific_mode(CMCalculatorRef ref);
void cm_calc_set_programmer_mode(CMCalculatorRef ref);
void cm_calc_send_command(CMCalculatorRef ref, int32_t command);

void cm_calc_set_radix(CMCalculatorRef ref, int32_t radixType);
void cm_calc_set_precision(CMCalculatorRef ref, int32_t precision);
void cm_calc_update_max_int_digits(CMCalculatorRef ref);
char* cm_calc_get_result_for_radix(CMCalculatorRef ref, uint32_t radix, int32_t precision, bool groupDigits);
bool cm_calc_is_input_empty(CMCalculatorRef ref);
int32_t cm_calc_get_current_degree_mode(CMCalculatorRef ref);

void cm_calc_memorize_number(CMCalculatorRef ref);
void cm_calc_memorized_load(CMCalculatorRef ref, uint32_t idx);
void cm_calc_memorized_add(CMCalculatorRef ref, uint32_t idx);
void cm_calc_memorized_subtract(CMCalculatorRef ref, uint32_t idx);
void cm_calc_memorized_clear(CMCalculatorRef ref, uint32_t idx);
void cm_calc_memorized_clear_all(CMCalculatorRef ref);
void cm_calc_set_memorized_numbers_string(CMCalculatorRef ref);

size_t cm_calc_history_count(CMCalculatorRef ref);
size_t cm_calc_history_count_for_mode(CMCalculatorRef ref, int32_t mode); // 0=Standard, 1=Scientific
size_t cm_calc_history_max_size(CMCalculatorRef ref);
bool cm_calc_history_get(CMCalculatorRef ref, uint32_t idx, char** outExpression, char** outResult);
bool cm_calc_history_get_for_mode(CMCalculatorRef ref, int32_t mode, uint32_t idx, char** outExpression, char** outResult);
bool cm_calc_history_load(CMCalculatorRef ref, uint32_t idx, bool isScientific, bool isFToE);
bool cm_calc_history_remove(CMCalculatorRef ref, uint32_t idx);
void cm_calc_history_clear(CMCalculatorRef ref);

// MARK: - UnitConverter C Bridge

typedef struct CMUnitConverterOpaque* CMUnitConverterRef;

typedef struct {
    int32_t id;
    const char* name;
    bool supportsNegative;
} CMCategoryDef;

typedef struct {
    int32_t id;
    const char* name;
    const char* accessibleName;
    const char* abbreviation;
    bool isSource;
    bool isTarget;
    bool isWhimsical;
} CMUnitDef;

typedef struct {
    int32_t fromUnitId;
    int32_t toUnitId;
    double ratio;
    double offset;
    bool offsetFirst;
} CMConversionRatioDef;

typedef struct {
    const char* value;
    int32_t unitId;
    const char* unitName;
    const char* unitAbbreviation;
    bool isWhimsical;
} CMSuggestedValue;

typedef struct {
    void* context;
    void (*onDisplay)(void* ctx, const char* fromDisplay, const char* toDisplay);
    void (*onSuggestedValues)(void* ctx, const CMSuggestedValue* values, size_t count);
    void (*onMaxDigitsReached)(void* ctx);
} CMUnitConverterCallbacks;

CMUnitConverterRef cm_uc_create(CMUnitConverterCallbacks callbacks);
void cm_uc_destroy(CMUnitConverterRef ref);

void cm_uc_begin_data(CMUnitConverterRef ref);
void cm_uc_add_category(CMUnitConverterRef ref, CMCategoryDef category, bool isCurrency);
void cm_uc_add_unit(CMUnitConverterRef ref, int32_t categoryId, CMUnitDef unit);
void cm_uc_add_ratio(CMUnitConverterRef ref, CMConversionRatioDef ratio);
void cm_uc_finish_data(CMUnitConverterRef ref);

void cm_uc_set_category(CMUnitConverterRef ref, int32_t categoryId, int32_t* outFromUnitId, int32_t* outToUnitId);
void cm_uc_set_unit_types(CMUnitConverterRef ref, int32_t fromUnitId, int32_t toUnitId);
void cm_uc_switch_active(CMUnitConverterRef ref, const char* newValue);
bool cm_uc_is_switched_active(CMUnitConverterRef ref);
void cm_uc_send_command(CMUnitConverterRef ref, int32_t command);
void cm_uc_calculate(CMUnitConverterRef ref);

#ifdef __cplusplus
}
#endif
