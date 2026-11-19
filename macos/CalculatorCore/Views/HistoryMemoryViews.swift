import SwiftUI

/// Exact port of `src/Calculator/Views/HistoryList.xaml`.
public struct HistoryListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm: StandardCalculatorViewModel

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(spacing: 0) {
            if vm.historyItems.isEmpty {
                HStack {
                    Text(res.string("HistoryEmpty.Text", fallback: "There’s no history yet."))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.historyItems) { item in
                            HistoryRowView(
                                item: item,
                                onSelect: { vm.selectHistoryItem(item) },
                                onCopy: { vm.copyValue(item.result) },
                                onDelete: { vm.deleteHistoryItem(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }

                // Clear all history button bottom-right
                HStack {
                    Spacer()
                    FluentCalcButton(variant: .subtle, action: { vm.clearHistory() }) {
                        CalcGlyphText(CalcGlyph.delete, size: 15)
                    }
                    .frame(width: 36, height: 36)
                    .help(res.string("ClearHistory.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Clear all history"))
                    .padding(6)
                }
            }
        }
    }
}

private struct HistoryRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let item: HistoryItem
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared
        Button(action: onSelect) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.expression)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(item.result)
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous)
                    .fill(isHovered ? theme.subtleFillHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(res.string("CopyHistoryMenuItem.Text", fallback: "Copy")) { onCopy() }
            Button(res.string("DeleteHistoryMenuItem.Text", fallback: "Delete")) { onDelete() }
        }
    }
}

/// Exact port of `src/Calculator/Views/Memory.xaml` & `MemoryListItem.xaml`.
public struct MemoryListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm: StandardCalculatorViewModel

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        VStack(spacing: 0) {
            if vm.memorizedNumbers.isEmpty {
                HStack {
                    Text(res.string("MemoryPaneEmpty.Text", fallback: "There’s nothing saved in memory."))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.memorizedNumbers) { item in
                            MemoryRowView(
                                item: item,
                                isDisabled: vm.isInError,
                                onRecall: { vm.memoryRecall(at: item.position) },
                                onClear: { vm.memoryClearItem(at: item.position) },
                                onAdd: { vm.memoryAdd(at: item.position) },
                                onSubtract: { vm.memorySubtract(at: item.position) }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }

                // Clear all memory button bottom-right
                HStack {
                    Spacer()
                    FluentCalcButton(variant: .subtle, action: { vm.memoryClearAll() }) {
                        CalcGlyphText(CalcGlyph.delete, size: 15)
                    }
                    .frame(width: 36, height: 36)
                    .help(res.string("ClearMemory.[using:Windows.UI.Xaml.Controls]ToolTipService.ToolTip", fallback: "Clear all memory (Ctrl+L)"))
                    .padding(6)
                }
            }
        }
    }
}

private struct MemoryRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let item: MemoryItem
    let isDisabled: Bool
    let onRecall: () -> Void
    let onClear: () -> Void
    let onAdd: () -> Void
    let onSubtract: () -> Void

    var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared
        VStack(alignment: .trailing, spacing: 4) {
            Text(item.value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isDisabled ? theme.textDisabled : theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 2) {
                Spacer()
                hoverMiniButton("MC", action: onClear)
                hoverMiniButton("M+", action: onAdd)
                hoverMiniButton("M-", action: onSubtract)
            }
            .opacity(isHovered ? 1 : 0)
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous)
                .fill(isHovered ? theme.subtleFillHover : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled { onRecall() }
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(res.string("ClearMemoryMenuItem.Text", fallback: "Clear memory item")) { onClear() }
            Button(res.string("MemPlusMenuItem.Text", fallback: "Add to memory item")) { onAdd() }
            Button(res.string("MemMinusMenuItem.Text", fallback: "Subtract from memory item")) { onSubtract() }
        }
    }

    private func hoverMiniButton(_ title: String, action: @escaping () -> Void) -> some View {
        FluentCalcButton(variant: .numeric, isEnabled: !isDisabled, action: action) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
        }
        .frame(width: 36, height: 28)
    }
}

/// Docked right-hand Pivot panel matching `DockPanel` / `DockPivot` in `src/Calculator/Views/Calculator.xaml` (visible when width >= 560pt).
public struct DockedHistoryMemoryPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: StandardCalculatorViewModel

    public init(vm: StandardCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let res = ResourceProvider.shared
        let showHistory = !vm.isProgrammer

        VStack(spacing: 0) {
            // Pivot header tabs (height 48 matching PivotHeaderItem in Calculator.xaml)
            HStack(spacing: 16) {
                if showHistory {
                    pivotTab(
                        title: res.string("HistoryLabel.Text", fallback: "History"),
                        isSelected: vm.selectedDockTab == 0,
                        action: { vm.selectedDockTab = 0 }
                    )
                }
                pivotTab(
                    title: res.string("MemoryLabel.Text", fallback: "Memory"),
                    isSelected: !showHistory || vm.selectedDockTab == 1,
                    action: { vm.selectedDockTab = 1 }
                )
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            if showHistory && vm.selectedDockTab == 0 {
                HistoryListView(vm: vm)
            } else {
                MemoryListView(vm: vm)
            }
        }
        .onChange(of: vm.isProgrammer) { _, isProg in
            if isProg { vm.selectedDockTab = 1 }
        }
    }

    private func pivotTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? theme.accentDefault : .clear)
                    .frame(width: 16, height: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
