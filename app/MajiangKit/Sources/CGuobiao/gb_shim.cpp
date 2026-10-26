#include "gb_shim.h"
#include "vendor/fan_calculator.h"
#include "vendor/shanten.h"
#include <string.h>

using namespace mahjong;

static bool fill_hand(const gb_meld_t *melds, int meld_count,
                      const uint8_t *standing, int standing_count,
                      hand_tiles_t *hand) {
    if (meld_count < 0 || meld_count > 4 || standing_count < 0 || standing_count > 13) {
        return false;
    }
    memset(hand, 0, sizeof(*hand));
    for (int i = 0; i < meld_count; ++i) {
        hand->fixed_packs[i] = make_pack(melds[i].offer, melds[i].type, melds[i].tile);
    }
    hand->pack_count = meld_count;
    memcpy(hand->standing_tiles, standing, standing_count);
    hand->tile_count = standing_count;
    return true;
}

int gb_fan_table_size(void) {
    return FAN_TABLE_SIZE;
}

int gb_fan_value(int fan_index) {
    if (fan_index <= 0 || fan_index >= FAN_TABLE_SIZE) {
        return 0;
    }
    return fan_value_table[fan_index];
}

int gb_calculate(const gb_meld_t *melds, int meld_count,
                 const uint8_t *standing, int standing_count,
                 uint8_t win_tile, uint8_t flower_count, uint8_t win_flag,
                 int prevalent_wind, int seat_wind,
                 uint16_t *out_table) {
    calculate_param_t param;
    if (!fill_hand(melds, meld_count, standing, standing_count, &param.hand_tiles)) {
        return GB_ERROR_WRONG_TILES_COUNT;
    }
    param.win_tile = win_tile;
    param.flower_count = flower_count;
    param.win_flag = win_flag;
    param.prevalent_wind = static_cast<wind_t>(prevalent_wind & 3);
    param.seat_wind = static_cast<wind_t>(seat_wind & 3);

    fan_table_t table;
    memset(table, 0, sizeof(table));
    int result = calculate_fan(&param, &table);
    memcpy(out_table, table, sizeof(table));
    return result;
}

int gb_waiting_tiles(const gb_meld_t *melds, int meld_count,
                     const uint8_t *standing, int standing_count,
                     uint8_t *out_tiles) {
    hand_tiles_t hand;
    if (!fill_hand(melds, meld_count, standing, standing_count, &hand)) {
        return 0;
    }
    useful_table_t useful;
    memset(useful, 0, sizeof(useful));
    if (!is_waiting(hand, &useful)) {
        return 0;
    }
    int n = 0;
    for (int i = 0; i < 34; ++i) {
        if (useful[all_tiles[i]]) {
            out_tiles[n++] = all_tiles[i];
        }
    }
    return n;
}
