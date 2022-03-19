//
//  SegmentedPicker.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.03.22.
//
import SwiftUI
import SlidingRuler

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
struct BackgroundGeometryReader: View {
    var body: some View {
        GeometryReader { geometry in
            return Color
                    .clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
    }
}
struct SizeAwareViewModifier: ViewModifier {

    @Binding private var viewSize: CGSize

    init(viewSize: Binding<CGSize>) {
        self._viewSize = viewSize
    }

    func body(content: Content) -> some View {
        content
            .background(BackgroundGeometryReader())
            .onPreferenceChange(SizePreferenceKey.self, perform: { if self.viewSize != $0 { self.viewSize = $0 }})
    }
}

struct SegmentedPicker: View {
    private static let ActiveSegmentColor: Color = Color(.tertiarySystemBackground)
    private static let BackgroundColor: Color = .black//Color(.secondarySystemBackground)
    private static let ShadowColor: Color = Color.black.opacity(0.2)
    private static let TextColor: Color = Color(.secondaryLabel)
    private static let SelectedTextColor: Color = .red
    
    private static let SegmentCornerRadius: CGFloat = 20
    private static let ShadowRadius: CGFloat = 4
    private static let SegmentXPadding: CGFloat = 16
    private static let SegmentYPadding: CGFloat = 8
    private static let PickerPadding: CGFloat = 4
    
    private static let AnimationDuration: Double = 0.1
    
    // Stores the size of a segment, used to create the active segment rect
    @State private var segmentSize: CGSize = .zero
    // Rounded rectangle to denote active segment
    private var activeSegmentView: AnyView {
        // Don't show the active segment until we have initialized the view
        // This is required for `.animation()` to display properly, otherwise the animation will fire on init
        let isInitialized: Bool = segmentSize != .zero
        if !isInitialized { return EmptyView().eraseToAnyView() }
        return
            RoundedRectangle(cornerRadius: SegmentedPicker.SegmentCornerRadius)
            .foregroundColor(expanded ? SegmentedPicker.ActiveSegmentColor : Color.clear)
                .shadow(color: SegmentedPicker.ShadowColor, radius: SegmentedPicker.ShadowRadius)
                .frame(width: self.segmentSize.width, height: self.segmentSize.height)
                .offset(x: self.computeActiveSegmentHorizontalOffset(), y: 0)
                .animation(Animation.easeOut(duration: SegmentedPicker.AnimationDuration))
                .eraseToAnyView()
    }
    
    @State var expanded = false
    @State private var selection: Int = 0
    
    @Binding private var focusValue: Double
    
    @Binding private var isoValue: Float
    @Binding private var isoMin: Float
    @Binding private var isoMax: Float
    
    private let onFocusChanged: (Bool) -> ()
    
    private let items: [String] = ["FOCUS", "ISO", "MORE"]
    
    init(focusValue: Binding<Double>,
         onFocusChanged: @escaping (Bool) -> (),
         isoValue: Binding<Float>,
         isoMin: Binding<Float>,
         isoMax: Binding<Float>) {
        self._focusValue = focusValue
        self._isoValue = isoValue
        self._isoMin = isoMin
        self._isoMax = isoMax
        
        self.onFocusChanged = onFocusChanged
    }
    
    var body: some View {
        // Align the ZStack to the leading edge to make calculating offset on activeSegmentView easier
        VStack {
            ZStack(alignment: .leading) {
                // activeSegmentView indicates the current selection
                self.activeSegmentView
                HStack {
                    ForEach(0..<self.items.count, id: \.self) { index in
                        self.getSegmentView(for: index)
                    }
                }
            }
            .padding(SegmentedPicker.PickerPadding)
            
            if (expanded) {
                VStack {
                    Divider()
                    ZStack {
                        SlidingRuler(value: $focusValue,
                                     in: 0...1,
                                     step: 0.5,
                                     tick: .fraction,
                                     onEditingChanged: onFocusChanged
                        ).padding(.bottom).opacity(selection == 0 ? 1 : 0)
                        SlidingRuler(value: $isoValue,
                                     in: isoMin...isoMax,
                                     step: 500.0,
                                     tick: .unit,
                                     onEditingChanged: {
                            (value) in
                            
                            //model.focusUpdate(value)
                            
                        }).padding(.bottom).opacity(selection == 1 ? 1 : 0)
                    }
                }.transition(.scale)
            }

        }
        .transition(.scale)
        .background(SegmentedPicker.BackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: SegmentedPicker.SegmentCornerRadius))

    }

    // Helper method to compute the offset based on the selected index
    private func computeActiveSegmentHorizontalOffset() -> CGFloat {
        CGFloat(self.selection) * (self.segmentSize.width + SegmentedPicker.SegmentXPadding / 2)
    }

    // Gets text view for the segment
    private func getSegmentView(for index: Int) -> some View {
        guard index < self.items.count else {
            return EmptyView().eraseToAnyView()
        }
        let isSelected = self.selection == index
        return
            Text(self.items[index])
                // Dark test for selected segment
                .foregroundColor(isSelected && expanded ? SegmentedPicker.SelectedTextColor: SegmentedPicker.TextColor)
                .lineLimit(1)
                .padding(.vertical, SegmentedPicker.SegmentYPadding)
                .padding(.horizontal, SegmentedPicker.SegmentXPadding)
                .frame(minWidth: 0, maxWidth: .infinity)
                // Watch for the size of the
                .modifier(SizeAwareViewModifier(viewSize: self.$segmentSize))
                .onTapGesture { self.onItemTap(index: index) }
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .eraseToAnyView()
    }

    // On tap to change the selection
    private func onItemTap(index: Int) {
        guard index < self.items.count else {
            return
        }
        withAnimation {
            if (index == self.selection || !self.expanded) {
                self.expanded.toggle()
            }
            self.selection = index
        }
    }
    
}
