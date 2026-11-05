import io
import unittest
import zipfile
from types import SimpleNamespace
from import_feed import read_schedule, normalize_vehicles, https_url


class Message(SimpleNamespace):
    def HasField(self, name):
        return hasattr(self, name)


def vehicle(timestamp=1000, **position):
    return Message(id='entity1', is_deleted=False, vehicle=Message(
        timestamp=timestamp, position=Message(latitude=42.5, longitude=27.47, **position),
        vehicle=Message(id='v1', label='Vehicle'), trip=Message(trip_id='t1', route_id='r1')))


def feed(*entities, incrementality=0):
    return Message(header=Message(incrementality=incrementality), entity=list(entities))


class ImportTests(unittest.TestCase):
    def schedule(self, stops):
        result = io.BytesIO()
        with zipfile.ZipFile(result, 'w') as archive:
            archive.writestr('stops.txt', 'stop_id,stop_name,stop_lat,stop_lon,location_type\n' + stops)
            archive.writestr('routes.txt', 'route_id,route_short_name\nr1,B1\n')
            archive.writestr('trips.txt', 'route_id,trip_id,trip_headsign\nr1,t1,Test destination\n')
        return result.getvalue()

    def test_stops_are_coordinates_from_data_not_guessed(self):
        stops, routes, trips = read_schedule(self.schedule('s1,Test stop,42.5,27.47,0\ne1,Entrance,42.5,27.47,2\n'))
        self.assertEqual(len(stops), 1)
        self.assertEqual(stops[0]['latitude'], 42.5)
        self.assertEqual(routes['r1'], 'B1')
        self.assertEqual(trips['t1'], ('r1', 'Test destination'))

    def test_invalid_or_empty_schedule_cannot_replace_stops(self):
        for text in ['', 's1,Stop,999,27.47,0\n', 's1,Stop,42.5,27.47,0\ns1,Duplicate,42.5,27.47,0\n']:
            with self.assertRaises(ValueError):
                read_schedule(self.schedule(text))

    def test_only_fresh_measurements_are_published(self):
        result = normalize_vehicles(feed(vehicle()), {'r1': 'B1'}, {'t1': ('r1', 'Destination')}, 1100)
        self.assertEqual(result['vehicles'][0]['observed_at'], 1000)
        self.assertEqual(result['vehicles'][0]['route'], 'B1')
        self.assertEqual(result['vehicles'][0]['label'], 'Destination')
        self.assertEqual(normalize_vehicles(feed(vehicle()), {}, {}, 1121)['vehicles'], [])
        self.assertEqual(normalize_vehicles(feed(vehicle(timestamp=1200)), {}, {}, 1100)['vehicles'], [])

    def test_missing_gps_timestamp_is_not_replaced_with_header_time(self):
        entity = vehicle()
        del entity.vehicle.timestamp
        result = normalize_vehicles(feed(entity), {}, {}, 1100)
        self.assertEqual(result['vehicles'], [])

    def test_differential_feed_is_rejected_instead_of_dropping_other_buses(self):
        with self.assertRaises(ValueError):
            normalize_vehicles(feed(vehicle(), incrementality=1), {}, {}, 1100)

    def test_duplicate_deleted_and_invalid_vehicles(self):
        deleted = vehicle(); deleted.is_deleted = True
        invalid = vehicle(); invalid.vehicle.position.latitude = float('nan')
        result = normalize_vehicles(feed(vehicle(), vehicle(), deleted, invalid), {}, {}, 1100)
        self.assertEqual(len(result['vehicles']), 1)

    def test_unsafe_endpoint_rejected(self):
        for url in ['http://host/feed', 'https://user:password@host/feed', 'file:///tmp/feed', 'https://host/#fragment']:
            with self.assertRaises(ValueError):
                https_url(url)
        self.assertEqual(https_url('https://host/feed'), 'https://host/feed')


if __name__ == '__main__':
    unittest.main()
