"""Server-side adapter for authorized GTFS + GTFS-Realtime VehiclePositions.

No guessed feed URLs or sample vehicles. Do not put service credentials in the app.
Run --help; read ../CATEGORY-PLACES-AND-TRANSIT.md before enabling publication.
"""
import argparse
import csv
import io
import json
import math
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

MAX_BYTES = 32 * 1024 * 1024


def coordinates(lat, lon):
    lat, lon = float(lat), float(lon)
    if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError("Invalid coordinates")
    return lat, lon


def read_schedule(data):
    """Read without extracting files; reject invalid/duplicate stops before replacing any."""
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        def rows(filename, required=False):
            matches = [n for n in archive.namelist() if n.rsplit('/', 1)[-1] == filename]
            if not matches and not required:
                return []
            if len(matches) != 1:
                raise ValueError("Expected exactly one " + filename)
            info = archive.getinfo(matches[0])
            if info.file_size > MAX_BYTES:
                raise ValueError("GTFS file exceeds size limit")
            return list(csv.DictReader(io.StringIO(archive.read(info).decode('utf-8-sig'))))

        stops, ids = [], set()
        for row in rows('stops.txt', required=True):
            # GTFS location_type=0 (or blank) represents a stop/platform.
            if row.get('location_type', '') not in ('', '0'):
                continue
            lat, lon = coordinates(row['stop_lat'], row['stop_lon'])
            identifier, name = row['stop_id'].strip(), row['stop_name'].strip()
            if not identifier or len(identifier) > 200 or not name or len(name) > 500 or identifier in ids:
                raise ValueError("Invalid or duplicate stop")
            ids.add(identifier)
            stops.append(dict(id=identifier, name=name, stop_code=row.get('stop_code') or None,
                              latitude=lat, longitude=lon))
        if not stops or len(stops) > 20000:
            raise ValueError("Expected 1–20000 stops")
        routes = {r['route_id']: r.get('route_short_name') or r.get('route_long_name') or '' for r in rows('routes.txt')}
        trips = {r['trip_id']: (r['route_id'], r.get('trip_headsign', '')) for r in rows('trips.txt')}
        return stops, routes, trips


def normalize_vehicles(feed, routes, trips, now):
    if not feed.HasField('header') or feed.header.incrementality != 0:
        raise ValueError("Only FULL_DATASET feeds are supported")
    vehicles, ids = [], set()
    for entity in feed.entity:
        if entity.is_deleted or not entity.HasField('vehicle'):
            continue
        vehicle = entity.vehicle
        # Header timestamp is not a substitute for the actual GPS measurement timestamp.
        if not vehicle.HasField('timestamp') or not vehicle.HasField('position'):
            continue
        age = now - vehicle.timestamp
        if age < -30 or age > 120:
            continue
        pos = vehicle.position
        if not pos.HasField('latitude') or not pos.HasField('longitude'):
            continue
        try:
            lat, lon = coordinates(pos.latitude, pos.longitude)
        except ValueError:
            continue
        identifier = vehicle.vehicle.id or entity.id
        if not identifier or identifier in ids:
            continue
        ids.add(identifier)
        trip_route, headsign = trips.get(vehicle.trip.trip_id, ('', ''))
        route_id = vehicle.trip.route_id or trip_route
        bearing = float(pos.bearing) if pos.HasField('bearing') and math.isfinite(pos.bearing) and 0 <= pos.bearing < 360 else None
        vehicles.append(dict(id=identifier, route=routes.get(route_id, ''), label=headsign or vehicle.vehicle.label,
                             latitude=lat, longitude=lon, bearing=bearing, observed_at=int(vehicle.timestamp)))
    return dict(vehicles=vehicles, fetched_at=now)


def decode_live(data, routes, trips, now):
    from google.transit import gtfs_realtime_pb2
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(data)
    if not feed.IsInitialized():
        raise ValueError("Incomplete GTFS-Realtime message")
    return normalize_vehicles(feed, routes, trips, now)


def https_url(value):
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.fragment:
        raise ValueError("Expected an HTTPS URL without embedded credentials")
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    # Do not forward provider/service headers to another host on a redirect.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Redirect refused; configure the final authorized HTTPS endpoint")


def request(url, headers=None, body=None):
    payload = None if body is None else json.dumps(body, allow_nan=False).encode()
    req = urllib.request.Request(https_url(url), data=payload, headers=headers or {})
    with urllib.request.build_opener(NoRedirect).open(req, timeout=20) as response:
        data = response.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise ValueError("Response exceeds size limit")
        return data


def source(env_name):
    # Provider-specific access headers are configured only on the server after approval.
    headers = json.loads(os.environ.get('BURGASBUS_HEADERS_JSON', '{}'))
    return request(os.environ[env_name], headers=headers)


def publish(path, value, prefer=None):
    base = https_url(os.environ['SUPABASE_URL'].rstrip('/'))
    key = os.environ['SUPABASE_SERVICE_ROLE_KEY']
    headers = {'apikey': key, 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}
    if prefer:
        headers['Prefer'] = prefer
    request(base + '/rest/v1/' + path, headers=headers, body=value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--schedule-file', type=Path, help='An authorized GTFS zip; otherwise use BURGASBUS_GTFS_URL')
    parser.add_argument('--live-file', type=Path, help='An authorized VehiclePositions protobuf; otherwise use BURGASBUS_VEHICLES_URL')
    parser.add_argument('--publish', action='store_true', help='Write to Supabase using SERVER credentials')
    parser.add_argument('--watch', action='store_true', help='Poll positions every 20 seconds; refresh GTFS daily (respect provider limits)')
    args = parser.parse_args()
    if args.watch and (args.live_file or args.schedule_file):
        parser.error('--watch requires live endpoints, not fixtures/files')
    refreshed = 0
    routes, trips = {}, {}
    while True:
        try:
            now = time.time()
            if now - refreshed >= 86400:
                schedule = args.schedule_file.read_bytes() if args.schedule_file else source('BURGASBUS_GTFS_URL')
                stops, routes, trips = read_schedule(schedule)
                if args.publish:
                    publish('rpc/replace_burgasbus_stops', {'p_stops': stops})
                refreshed = now
                print(f'Validated {len(stops)} official stop records.', flush=True)
            data = args.live_file.read_bytes() if args.live_file else source('BURGASBUS_VEHICLES_URL')
            snapshot = decode_live(data, routes, trips, time.time())
            if args.publish:
                publish('burgasbus_live?on_conflict=id', {'id': 1, 'payload': snapshot}, 'resolution=merge-duplicates')
            print(f'Validated {len(snapshot["vehicles"])} fresh vehicle positions.', flush=True)
        except Exception as error:
            # Exceptions from remote servers can contain URLs/tokens: do not print their text.
            print(f'Import failed ({type(error).__name__}); existing GPS positions expire automatically.', flush=True)
            if not args.watch:
                raise SystemExit(1)
        if not args.watch:
            return
        time.sleep(20)


if __name__ == '__main__':
    main()
