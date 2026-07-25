import SwiftUI
import MapKit

struct ManualPinView: View {
    @Binding var selectedPlace: SelectedPlace?
    var initialCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var placeName = ""
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var locationService = LocationService()
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    init(selectedPlace: Binding<SelectedPlace?>, initialCoordinate: CLLocationCoordinate2D?) {
        _selectedPlace = selectedPlace
        if let coord = initialCoordinate {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 200,
                longitudinalMeters: 200
            )))
        } else {
            _cameraPosition = State(initialValue: .userLocation(fallback: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search input
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索店铺名称", text: $placeName)
                        .textFieldStyle(.plain)
                    if !placeName.isEmpty {
                        Button {
                            placeName = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: placeName) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        guard !Task.isCancelled else { return }
                        await performSearch(query: newValue)
                    }
                }

                // Search results list
                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button {
                            selectSearchResult(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "未知地点")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                                Text(item.placemark.formattedAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 200)
                } else {
                    // Map
                    mapContent
                }
            }
            .navigationTitle("手动标注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { confirmPin() }
                        .disabled(placeName.isEmpty || pinCoordinate == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if #available(iOS 18.0, *) {
            MapWithFeatureSelection(
                cameraPosition: $cameraPosition,
                pinCoordinate: $pinCoordinate,
                placeName: $placeName
            )
        } else {
            MapWithCenterPin(
                cameraPosition: $cameraPosition,
                pinCoordinate: $pinCoordinate,
                placeName: $placeName
            )
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coord = locationService.currentLocation {
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        placeName = item.name ?? ""
        pinCoordinate = coord
        searchResults = []

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 200,
                longitudinalMeters: 200
            ))
        }
    }

    private func confirmPin() {
        guard let coord = pinCoordinate else { return }
        Task {
            let geo = await locationService.reverseGeocode(coordinate: coord)
            selectedPlace = SelectedPlace(
                name: placeName,
                placeId: nil,
                address: geo?.address ?? "",
                latitude: coord.latitude,
                longitude: coord.longitude,
                country: geo?.country ?? "",
                province: geo?.province ?? "",
                city: geo?.city ?? "",
                district: geo?.district ?? ""
            )
            dismiss()
        }
    }
}

// MARK: - Placemark address helper

extension CLPlacemark {
    var formattedAddress: String {
        [administrativeArea, locality, subLocality, thoroughfare, subThoroughfare]
            .compactMap { $0 }
            .joined()
    }
}

// iOS 18+: tap POI to select
@available(iOS 18.0, *)
private struct MapWithFeatureSelection: View {
    @Binding var cameraPosition: MapCameraPosition
    @Binding var pinCoordinate: CLLocationCoordinate2D?
    @Binding var placeName: String
    @State private var selectedFeature: MapFeature?

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedFeature) {
            if let pinCoordinate {
                Marker(placeName, coordinate: pinCoordinate)
                    .tint(.red)
            }
        }
        .mapFeatureSelectionAccessory(.callout)
        .onChange(of: selectedFeature) { _, feature in
            guard let feature else { return }
            placeName = feature.title ?? ""
            pinCoordinate = feature.coordinate
        }
    }
}

// iOS 17: drag map, pin stays at center, geocode on stop
private struct MapWithCenterPin: View {
    @Binding var cameraPosition: MapCameraPosition
    @Binding var pinCoordinate: CLLocationCoordinate2D?
    @Binding var placeName: String

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                if let pinCoordinate {
                    Marker(placeName, coordinate: pinCoordinate)
                        .tint(.red)
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                if pinCoordinate == nil {
                    pinCoordinate = context.region.center
                }
            }

            if pinCoordinate == nil {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                    .offset(y: -16)
            }
        }
    }
}
