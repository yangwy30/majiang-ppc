// C interface over the vendored ChineseOfficialMahjongHelper algorithm (MIT, see vendor/LICENSE).
// Swift only sees this header; the C++ types stay inside gb_shim.cpp.
#ifndef GB_SHIM_H
#define GB_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Tile encoding is the library's: high nibble = suit (1 万 m, 2 条 s, 3 饼 p, 4 字), low nibble = rank.
// Honors: 1 东 2 南 3 西 4 北 5 中 6 发 7 白.

#define GB_MELD_CHOW 1
#define GB_MELD_PUNG 2
#define GB_MELD_KONG 3

typedef struct {
    uint8_t type;   // GB_MELD_*
    uint8_t tile;   // chow: the middle tile; pung / kong: the tile
    uint8_t offer;  // 0 = concealed (only meaningful for a kong), 1-3 = claimed from a player
} gb_meld_t;

#define GB_FLAG_DISCARD        0
#define GB_FLAG_SELF_DRAWN     1
#define GB_FLAG_LAST_TILE      2   // 和绝张
#define GB_FLAG_KONG_INVOLVED  4   // 杠上开花 (self-drawn) / 抢杠和 (discard)
#define GB_FLAG_WALL_LAST      8   // 妙手回春 (self-drawn) / 海底捞月 (discard)

#define GB_ERROR_WRONG_TILES_COUNT -1
#define GB_ERROR_TILE_MORE_THAN_4  -2
#define GB_ERROR_NOT_WIN           -3

// Number of entries in the fan table (index 0 is unused).
int gb_fan_table_size(void);

// Point value of one fan, by table index.
int gb_fan_value(int fan_index);

// Calculates the hand. `standing` excludes the winning tile; 3 * meld_count + standing_count must be 13.
// Winds: 0 东 1 南 2 西 3 北. Writes fan counts into out_table (gb_fan_table_size() entries).
// Returns the total fan (> 0) or a GB_ERROR_* code.
int gb_calculate(const gb_meld_t *melds, int meld_count,
                 const uint8_t *standing, int standing_count,
                 uint8_t win_tile, uint8_t flower_count, uint8_t win_flag,
                 int prevalent_wind, int seat_wind,
                 uint16_t *out_table);

// Tiles that would complete the hand (any shape, ignoring the 8-fan minimum).
// 3 * meld_count + standing_count must be 13. Writes up to 34 tiles, returns how many.
int gb_waiting_tiles(const gb_meld_t *melds, int meld_count,
                     const uint8_t *standing, int standing_count,
                     uint8_t *out_tiles);

#ifdef __cplusplus
}
#endif

#endif
