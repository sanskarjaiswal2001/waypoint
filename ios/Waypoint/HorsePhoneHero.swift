import SwiftUI

/// Shared decorative riding artwork, with a moving map attached to the phone.
struct HorsePhoneHero: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var origin = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active || reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSince(origin).truncatingRemainder(dividingBy: 6.4)
                let phase = time / 1.28 * .pi * 2
                let scale = min(size.width / 1080, size.height / 1400)
                var scene = context
                scene.translateBy(x: (size.width - 1080 * scale) / 2, y: 0)
                scene.scaleBy(x: scale, y: scale)
                scene.translateBy(x: sin(phase) * 5, y: sin(phase * 2) * 6)
                scene.translateBy(x: 540, y: 1080); scene.rotate(by: .degrees(sin(phase) * 0.25)); scene.translateBy(x: -540, y: -1080)
                if let rider = SharedArt.image("onboarding_horse_pov") { scene.draw(Image(uiImage: rider), in: CGRect(x: 0, y: 0, width: 1080, height: 1600)) }
                var phone = scene
                phone.clip(to: Path(roundedRect: CGRect(x: 143, y: 829, width: 793, height: 296), cornerRadius: 20))
                if let map = SharedArt.image("onboarding_horse_map") { phone.draw(Image(uiImage: map), in: CGRect(x: 143, y: 189 + time / 6.4 * 640, width: 794, height: 1280)) }
                phone.fill(Path(roundedRect: CGRect(x: 164, y: 846, width: 267, height: 65), cornerRadius: 12), with: .color(Color(hex: "242824")))
                var arrow = Path(); arrow.move(to: CGPoint(x: 192, y: 891)); arrow.addLine(to: CGPoint(x: 192, y: 865)); arrow.move(to: CGPoint(x: 181, y: 877)); arrow.addLine(to: CGPoint(x: 192, y: 865)); arrow.addLine(to: CGPoint(x: 203, y: 877))
                phone.stroke(arrow, with: .color(Color(hex: "FFF5DE")), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                phone.draw(Text("Continue straight").font(SharedArt.font("nunito", 22)).bold().foregroundStyle(Color(hex: "FFF5DE")), at: CGPoint(x: 218, y: 886), anchor: .bottomLeading)
                var marker = Path(); marker.move(to: CGPoint(x: 520, y: 1015)); marker.addCurve(to: CGPoint(x: 495, y: 1056), control1: CGPoint(x: 507, y: 1028), control2: CGPoint(x: 495, y: 1041)); marker.addCurve(to: CGPoint(x: 545, y: 1056), control1: CGPoint(x: 495, y: 1090), control2: CGPoint(x: 545, y: 1090)); marker.addCurve(to: CGPoint(x: 520, y: 1015), control1: CGPoint(x: 545, y: 1041), control2: CGPoint(x: 533, y: 1028)); marker.closeSubpath()
                phone.fill(marker, with: .color(Color(hex: "FFFDF0"))); phone.stroke(marker, with: .color(Color(hex: "161B19")), lineWidth: 5); phone.fill(Path(ellipseIn: CGRect(x: 509, y: 1045, width: 22, height: 22)), with: .color(Color(hex: "171B19")))
                if let horn = SharedArt.image("onboarding_saddle_horn") { scene.draw(Image(uiImage: horn), in: CGRect(x: 365, y: 1055, width: 125, height: 130)) }
            }
            .overlay(alignment: .topLeading) { sticker("onboarding_marker_parking").rotationEffect(.degrees(-10)).padding(.top, 70) }
            .overlay(alignment: .topTrailing) { sticker("onboarding_marker_sights").rotationEffect(.degrees(9)).padding(.top, 162) }
        }.allowsHitTesting(false)
    }
    @ViewBuilder private func sticker(_ name: String) -> some View {
        if let image = SharedArt.image(name) { Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 64) }
    }
}
