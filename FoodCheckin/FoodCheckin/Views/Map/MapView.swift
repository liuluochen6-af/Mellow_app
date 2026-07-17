import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedPin: MapPin? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, selection: $selectedPin) {
                ForEach(viewModel.visitedPolygons, id: \.id) { polygon in
                    MapPolygon(coordinates: polygon.coordinates)
                        .foregroundStyle(fillColor.opacity(0.3))
                        .stroke(fillColor.opacity(0.6), lineWidth: 1)
                }

                ForEach(viewModel.pins) { pin in
                    Annotation(pin.placeName, coordinate: pin.coordinate) {
                        PinMarkerView(pin: pin, isSelected: selectedPin?.id == pin.id)
                            .onTapGesture {
                                selectedPin = selectedPin?.id == pin.id ? nil : pin
                            }
                    }
                    .tag(pin)
                }
            }
            .mapStyle(.standard)
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.updateVisibleRegion(context.region)
            }
            .ignoresSafeArea(edges: .bottom)

            // Top overlay header
            HStack {
                Button { } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // Region dropdown
                Menu {
                    ForEach(viewModel.availableRegions) { region in
                        Button {
                            selectRegion(region)
                        } label: {
                            HStack {
                                Text(region.name)
                                Spacer()
                                Text("\(region.pinCount) 店铺")
                                if viewModel.selectedRegion == region.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedRegion)
                            .font(.headline)
                            .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                Spacer()

                Button {
                    viewModel.selectedRegion = "全球"
                    withAnimation { cameraPosition = .automatic }
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Pin detail card at bottom
            if let pin = selectedPin {
                VStack {
                    Spacer()
                    PinDetailCard(pin: pin)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private var fillColor: Color {
        Color(red: 0.76, green: 0.6, blue: 0.42)
    }

    private func selectRegion(_ region: MapRegionOption) {
        viewModel.selectedRegion = region.name
        if let center = region.center, let span = region.span {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        } else {
            withAnimation {
                cameraPosition = .automatic
            }
        }
    }
}
