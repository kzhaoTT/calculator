import SwiftUI

/// Exact port of `src/Calculator/Views/DateCalculator.xaml`.
public struct DateCalculatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: DateCalculatorViewModel

    @State private var showFromPopover = false
    @State private var showToPopover = false
    @State private var showStartPopover = false

    public init(vm: DateCalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let res = ResourceProvider.shared

        GeometryReader { geo in
            let isWide = geo.size.width >= 480
            let resultFontSize: CGFloat = isWide ? 22 : 16

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 48)

                    // Option Dropdown ("Difference between dates" / "Add or subtract days")
                    Menu {
                        ForEach(DateCalcOption.allCases) { opt in
                            Button(opt.title) {
                                vm.selectedOption = opt
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(vm.selectedOption.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            CalcGlyphText(CalcGlyph.chevronDown, size: 11)
                                .foregroundStyle(theme.textPrimary)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .padding(.bottom, 16)

                    if vm.isDateDiffMode {
                        // Difference between dates layout
                        VStack(alignment: .leading, spacing: 20) {
                            dateFieldRow(
                                label: res.string("DateDiff_FromHeader.Header", fallback: "From"),
                                date: $vm.fromDate,
                                isPopoverOpen: $showFromPopover
                            )

                            dateFieldRow(
                                label: res.string("DateDiff_ToHeader.Header", fallback: "To"),
                                date: $vm.toDate,
                                isPopoverOpen: $showToPopover
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(res.string("Date_DifferenceLabel.Text", fallback: "Difference"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textSecondary)

                                Text(vm.strDateDiffResult)
                                    .font(.system(size: resultFontSize, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                    .textSelection(.enabled)
                                    .contextMenu {
                                        Button(res.string("copyMenuItem", fallback: "Copy")) { vm.copyResult() }
                                    }

                                if !vm.isDiffInDaysOnly && !vm.strDateDiffResultInDays.isEmpty {
                                    Text(vm.strDateDiffResultInDays)
                                        .font(.system(size: 13))
                                        .foregroundStyle(theme.textSecondary)
                                        .textSelection(.enabled)
                                        .contextMenu {
                                            Button(res.string("copyMenuItem", fallback: "Copy")) { vm.copyResult() }
                                        }
                                }
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        // Add or subtract days layout
                        VStack(alignment: .leading, spacing: 22) {
                            dateFieldRow(
                                label: res.string("AddSubtract_Date_FromHeader.Header", fallback: "From"),
                                date: $vm.startDate,
                                isPopoverOpen: $showStartPopover
                            )

                            // Add / Subtract Radio Buttons
                            HStack(spacing: 24) {
                                radioOption(
                                    title: res.string("AddOption.Content", fallback: "Add"),
                                    selected: vm.isAddMode,
                                    action: { vm.isAddMode = true }
                                )
                                radioOption(
                                    title: res.string("SubtractOption.Content", fallback: "Subtract"),
                                    selected: !vm.isAddMode,
                                    action: { vm.isAddMode = false }
                                )
                            }

                            // Years / Months / Days 0..999 ComboBoxes
                            HStack(spacing: 12) {
                                offsetPicker(
                                    title: res.string("YearsLabel.Text", fallback: "Years"),
                                    selection: $vm.yearsOffset
                                )
                                offsetPicker(
                                    title: res.string("MonthsLabel.Text", fallback: "Months"),
                                    selection: $vm.monthsOffset
                                )
                                offsetPicker(
                                    title: res.string("DaysLabel.Text", fallback: "Days"),
                                    selection: $vm.daysOffset
                                )
                            }

                            // Resulting Date
                            VStack(alignment: .leading, spacing: 6) {
                                Text(res.string("DateLabel.Text", fallback: "Date"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textSecondary)

                                Text(vm.strDateResult)
                                    .font(.system(size: resultFontSize, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                    .textSelection(.enabled)
                                    .contextMenu {
                                        Button(res.string("copyMenuItem", fallback: "Copy")) { vm.copyResult() }
                                    }
                            }
                            .padding(.top, 4)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: 456, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dateFieldRow(label: String, date: Binding<Date>, isPopoverOpen: Binding<Bool>) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none

        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)

            Button {
                isPopoverOpen.wrappedValue.toggle()
            } label: {
                HStack(spacing: 10) {
                    Text(df.string(from: date.wrappedValue))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(theme.textPrimary)
                    CalcGlyphText(CalcGlyph.navDate, size: 15)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: CalcTheme.controlCornerRadius, style: .continuous)
                        .fill(theme.subtleFillHover)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: isPopoverOpen, arrowEdge: .bottom) {
                DatePicker("", selection: date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(10)
            }
        }
    }

    private func radioOption(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? theme.accentDefault : theme.textSecondary, lineWidth: selected ? 5 : 1.5)
                        .frame(width: 18, height: 18)
                }
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textPrimary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func offsetPicker(title: String, selection: Binding<Int>) -> some View {
        let theme = CalcTheme(colorScheme: colorScheme)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
            Picker("", selection: selection) {
                ForEach(0...DateCalculatorViewModel.maxOffsetValue, id: \.self) { val in
                    Text("\(val)").tag(val)
                }
            }
            .labelsHidden()
            .frame(width: 86)
        }
    }
}
