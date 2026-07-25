import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedPin: MapPin? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showRegionMenu = false
    @State private var showCheckInDetail = false

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, selection: $selectedPin) {
                ForEach(viewModel.visitedPolygons, id: \.id) { polygon in
                    MapPolygon(coordinates: polygon.coordinates)
                        .foregroundStyle(Color.black.opacity(0.08))
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                }

                ForEach(viewModel.pins) { pin in
                    Annotation(pin.placeName, coordinate: pin.coordinate) {
                        PinMarkerView(pin: pin, isSelected: selectedPin?.id == pin.id)
                            .onTapGesture {
                                if selectedPin?.id == pin.id {
                                    selectedPin = nil
                                } else {
                                    selectedPin = pin
                                    if !pin.city.isEmpty {
                                        viewModel.selectedRegion = pin.city
                                    }
                                    withAnimation {
                                        cameraPosition = .region(MKCoordinateRegion(
                                            center: pin.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                        ))
                                    }
                                }
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
                // Menu button - opens region list
                Button {
                    showRegionMenu = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color.black)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // Current region label
                Text(viewModel.selectedRegion)
                    .font(.headline)
                    .foregroundColor(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                Spacer()

                // Back to world button
                Button {
                    selectedPin = nil
                    viewModel.selectedRegion = "全球"
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
                            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
                        ))
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color.black)
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
                        .onTapGesture { showCheckInDetail = true }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showRegionMenu) {
            RegionMenuView(viewModel: viewModel) { region in
                selectRegion(region)
                showRegionMenu = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCheckInDetail) {
            if let pin = selectedPin {
                CheckInDetailView(checkInId: pin.id)
            }
        }
    }

    private var fillColor: Color {
        Color.black
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

// MARK: - Region Menu Sheet

struct RegionMenuView: View {
    @ObservedObject var viewModel: MapViewModel
    let onSelect: (MapRegionOption) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.availableRegions) { region in
                        Button {
                            onSelect(region)
                        } label: {
                            HStack {
                                Image(systemName: region.name == "全球" ? "globe.asia.australia" : "mappin.circle.fill")
                                    .foregroundColor(Color.black)
                                    .frame(width: 28)

                                Text(region.name)
                                    .foregroundColor(Color.primary)

                                Spacer()

                                Text("\(region.pinCount) 打卡")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if viewModel.selectedRegion == region.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.black)
                                        .font(.caption.bold())
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择区域跳转")
                }
            }
            .navigationTitle("地图区域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
