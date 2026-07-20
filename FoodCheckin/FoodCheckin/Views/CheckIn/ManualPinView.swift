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

    init(selectedPlace: Binding<SelectedPlace?>, initialCoordinate: CLLocationCoordinate2D?) {
        _selectedPlace = selectedPlace
        let coord = initialCoordinate ?? CLLocationCoordinate2D(latitude: 37.79, longitude: -122.41)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("输入地点名称", text: $placeName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()

                mapContent
            }
            .navigationTitle("手动标注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { confirmPin() }
                        .disabled(placeName.isEmpty)
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

    private func confirmPin() {
        let coord = pinCoordinate ?? CLLocationCoordinate2D(latitude: 37.79, longitude: -122.41)
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
    @State private var isGeocoding = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition)
                .onMapCameraChange(frequency: .onEnd) { context in
                    pinCoordinate = context.region.center
                    geocode(context.region.center)
                }

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
                .offset(y: -16)
        }
    }

    private func geocode(_ coordinate: CLLocationCoordinate2D) {
        isGeocoding = true
        Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                let name = placemark.name ?? placemark.thoroughfare ?? ""
                if !name.isEmpty {
                    placeName = name
                }
            }
            isGeocoding = false
        }
    }
}
