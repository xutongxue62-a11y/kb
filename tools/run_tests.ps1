param([string]$DataRoot = '', [string]$LogPrefix = 'v06_')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = if ($DataRoot) { [System.IO.Path]::GetFullPath((Join-Path $projectRoot $DataRoot)) } else { Join-Path $projectRoot 'runtime' }
$env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
$enginePath = Join-Path $projectRoot 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Push-Location -LiteralPath $projectRoot
try {
    foreach ($testName in @('rules', 'scene', 'controls', 'attack_links', 'growth', 'feedback', 'impact', 'progression', 'armory', 'save_store', 'hud_navigation', 'campaign', 'frontend', 'ui_motion', 'ui_audio', 'home_v09', 'chest_pickup', 'sprite_edges', 'dodge', 'music', 'world_camera', 'battle_ui_v10', 'map_chunks', 'terrain_physics', 'growth_v11', 'supports_v11', 'ui_v11', 'resources_v12', 'rounds_v12', 'weapons_v12', 'enemies_v12', 'battle_visuals_v12', 'class_egg_loadout', 'character_loot', 'settlement_v14', 'evolution_v14', 'weapon_presentation_v15', 'companions_v16', 'combat_art_v16', 'terrain_broadphase_v16', 'monster_surface_v16', 'pickup_renderer_v16', 'weapon_replace_v20', 'ui_brush_v22', 'reward_sale_v23', 'reward_buff_sale_v30', 'distribution_fonts', 'mobile_controls', 'release_updates', 'release_startup', 'feedback_balance_v32', 'feedback_takeover_v32', 'biome_encounters')) {
        $logPath = Join-Path $projectRoot ('logs\' + $LogPrefix + $testName + '.log')
        & $enginePath --headless --path $projectRoot --script ('res://tests/test_' + $testName + '.gd') --quit-after 600 --log-file $logPath *> $null
        $testExit = $LASTEXITCODE
        $testLog = Get-Content -LiteralPath $logPath
        $testLog | Select-Object -Last 5
        if ($testExit -ne 0 -or ($testLog -match 'ERROR:|SCRIPT ERROR|Parse Error|FAIL:') -or -not ($testLog -match 'RESULT:.*0 failures')) {
            throw ('Test failed: ' + $testName + ', exit=' + $testExit + ', log=' + $logPath)
        }
    }
} finally {
    Pop-Location
}
