/*
 * vterm_shim.c — Thin C shim bridging libvterm ↔ Chez Scheme FFI.
 *
 * Wraps libvterm's VTerm/VTermScreen with:
 *   - Scrollback ring buffer (sb_pushline/sb_popline callbacks)
 *   - Row-level damage tracking (dirty bitmask)
 *   - Alt-screen detection
 *   - Per-row text extraction (UTF-8)
 *   - Per-cell color + attribute queries
 *
 * Compile: cc -shared -fPIC -o vterm_shim.so vterm_shim.c -lvterm
 */

#include <vterm.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* ============================================================
 * Scrollback ring buffer
 * ============================================================
 * Each scrollback line stores UTF-8 text (variable length).
 * Ring buffer holds up to max_lines entries.
 */

#define JVT_DEFAULT_SCROLLBACK 10000

typedef struct {
    char *text;      /* UTF-8 text of this line (heap-allocated) */
    int   text_len;  /* length in bytes (not including NUL) */
} JvtScrollLine;

typedef struct {
    JvtScrollLine *lines;    /* ring buffer array */
    int            max_lines; /* capacity */
    int            count;     /* number of lines stored (0..max_lines) */
    int            head;      /* index of oldest line */
} JvtScrollback;

static void scrollback_init(JvtScrollback *sb, int max_lines) {
    sb->max_lines = max_lines;
    sb->count = 0;
    sb->head = 0;
    sb->lines = (JvtScrollLine *)calloc(max_lines, sizeof(JvtScrollLine));
}

static void scrollback_free(JvtScrollback *sb) {
    if (!sb->lines) return;
    for (int i = 0; i < sb->max_lines; i++) {
        free(sb->lines[i].text);
    }
    free(sb->lines);
    sb->lines = NULL;
}

/* Push a line (newest goes at tail end of ring) */
static void scrollback_push(JvtScrollback *sb, const char *text, int len) {
    int idx;
    if (sb->count < sb->max_lines) {
        idx = (sb->head + sb->count) % sb->max_lines;
        sb->count++;
    } else {
        /* Overwrite oldest */
        idx = sb->head;
        sb->head = (sb->head + 1) % sb->max_lines;
        free(sb->lines[idx].text);
    }
    sb->lines[idx].text = (char *)malloc(len + 1);
    memcpy(sb->lines[idx].text, text, len);
    sb->lines[idx].text[len] = '\0';
    sb->lines[idx].text_len = len;
}

/* Pop the newest line (for sb_popline — alt screen restore) */
static int scrollback_pop(JvtScrollback *sb, char *buf, int buflen) {
    if (sb->count == 0) return -1;
    sb->count--;
    int idx = (sb->head + sb->count) % sb->max_lines;
    int len = sb->lines[idx].text_len;
    if (buf && buflen > 0) {
        int copy = len < buflen ? len : buflen - 1;
        memcpy(buf, sb->lines[idx].text, copy);
        buf[copy] = '\0';
    }
    free(sb->lines[idx].text);
    sb->lines[idx].text = NULL;
    sb->lines[idx].text_len = 0;
    return len;
}

/* Get line by index (0 = newest/most recent, count-1 = oldest) */
static JvtScrollLine *scrollback_get(JvtScrollback *sb, int idx) {
    if (idx < 0 || idx >= sb->count) return NULL;
    /* idx 0 = newest = (head + count - 1), idx 1 = (head + count - 2), etc */
    int ring_idx = (sb->head + sb->count - 1 - idx) % sb->max_lines;
    return &sb->lines[ring_idx];
}

/* ============================================================
 * Main JVT wrapper struct
 * ============================================================ */

typedef struct {
    VTerm       *vt;
    VTermScreen *screen;
    int          rows;
    int          cols;

    /* Damage tracking: bitmask of dirty rows since last jvt_get_damage() */
    uint8_t     *dirty_rows;   /* 1 byte per row; 1 = dirty */
    int          any_damage;   /* quick flag: any row dirty? */

    /* Scrollback */
    JvtScrollback scrollback;

    /* Alt screen state */
    int          is_altscreen;

    /* Temp buffer for text extraction */
    char        *text_buf;
    int          text_buf_size;
} JvtState;

/* ============================================================
 * libvterm screen callbacks
 * ============================================================ */

static int cb_damage(VTermRect rect, void *user) {
    JvtState *st = (JvtState *)user;
    for (int r = rect.start_row; r < rect.end_row && r < st->rows; r++) {
        st->dirty_rows[r] = 1;
    }
    st->any_damage = 1;
    return 0;
}

static int cb_sb_pushline(int cols, const VTermScreenCell *cells, void *user) {
    JvtState *st = (JvtState *)user;

    /* Convert cells to UTF-8 text */
    /* Max 4 bytes per char × VTERM_MAX_CHARS_PER_CELL × cols */
    int max_len = cols * VTERM_MAX_CHARS_PER_CELL * 4;
    char *buf = (char *)malloc(max_len + 1);
    int pos = 0;

    for (int c = 0; c < cols; c++) {
        /* Encode each char as UTF-8 */
        for (int ci = 0; ci < VTERM_MAX_CHARS_PER_CELL && cells[c].chars[ci]; ci++) {
            uint32_t cp = cells[c].chars[ci];
            if (cp < 0x80) {
                buf[pos++] = (char)cp;
            } else if (cp < 0x800) {
                buf[pos++] = 0xC0 | (cp >> 6);
                buf[pos++] = 0x80 | (cp & 0x3F);
            } else if (cp < 0x10000) {
                buf[pos++] = 0xE0 | (cp >> 12);
                buf[pos++] = 0x80 | ((cp >> 6) & 0x3F);
                buf[pos++] = 0x80 | (cp & 0x3F);
            } else {
                buf[pos++] = 0xF0 | (cp >> 18);
                buf[pos++] = 0x80 | ((cp >> 12) & 0x3F);
                buf[pos++] = 0x80 | ((cp >> 6) & 0x3F);
                buf[pos++] = 0x80 | (cp & 0x3F);
            }
        }
        /* If cell has no chars, it's a space */
        if (cells[c].chars[0] == 0) {
            buf[pos++] = ' ';
        }
    }

    /* Trim trailing spaces */
    while (pos > 0 && buf[pos - 1] == ' ') pos--;

    buf[pos] = '\0';
    scrollback_push(&st->scrollback, buf, pos);
    free(buf);
    return 0;
}

static int cb_sb_popline(int cols, VTermScreenCell *cells, void *user) {
    JvtState *st = (JvtState *)user;
    if (st->scrollback.count == 0) return 0;

    /* We need to restore the line into cells. For simplicity, just fill
     * with spaces — libvterm handles alt-screen save/restore itself mostly.
     * The scrollback_pop removes the line from our buffer. */
    for (int c = 0; c < cols; c++) {
        memset(&cells[c], 0, sizeof(VTermScreenCell));
        cells[c].chars[0] = ' ';
        cells[c].width = 1;
    }

    /* Pop newest line and try to fill cells from its text */
    char tmpbuf[8192];
    int len = scrollback_pop(&st->scrollback, tmpbuf, sizeof(tmpbuf));
    if (len > 0) {
        int c = 0;
        int i = 0;
        while (i < len && c < cols) {
            unsigned char b = (unsigned char)tmpbuf[i];
            uint32_t cp;
            int bytes;
            if (b < 0x80) { cp = b; bytes = 1; }
            else if (b < 0xE0) { cp = b & 0x1F; bytes = 2; }
            else if (b < 0xF0) { cp = b & 0x0F; bytes = 3; }
            else { cp = b & 0x07; bytes = 4; }
            for (int j = 1; j < bytes && (i + j) < len; j++)
                cp = (cp << 6) | (tmpbuf[i + j] & 0x3F);
            cells[c].chars[0] = cp;
            cells[c].width = 1;
            i += bytes;
            c++;
        }
    }
    return 1;
}

static int cb_settermprop(VTermProp prop, VTermValue *val, void *user) {
    JvtState *st = (JvtState *)user;
    if (prop == VTERM_PROP_ALTSCREEN) {
        st->is_altscreen = val->boolean;
    }
    return 1;
}

static int cb_movecursor(VTermPos pos, VTermPos oldpos, int visible, void *user) {
    (void)pos; (void)oldpos; (void)visible; (void)user;
    return 1;
}

static int cb_bell(void *user) {
    (void)user;
    return 0;
}

static int cb_resize(int rows, int cols, void *user) {
    (void)rows; (void)cols; (void)user;
    return 1;
}

static VTermScreenCallbacks screen_cbs = {
    .damage      = cb_damage,
    .moverect    = NULL,
    .movecursor  = cb_movecursor,
    .settermprop = cb_settermprop,
    .bell        = cb_bell,
    .resize      = cb_resize,
    .sb_pushline = cb_sb_pushline,
    .sb_popline  = cb_sb_popline,
    .sb_clear    = NULL,
};

/* ============================================================
 * Public API
 * ============================================================ */

void *jvt_new(int rows, int cols) {
    JvtState *st = (JvtState *)calloc(1, sizeof(JvtState));
    if (!st) return NULL;

    st->vt = vterm_new(rows, cols);
    if (!st->vt) { free(st); return NULL; }

    vterm_set_utf8(st->vt, 1);

    st->screen = vterm_obtain_screen(st->vt);
    st->rows = rows;
    st->cols = cols;

    /* Allocate damage tracking BEFORE setting callbacks (screen_reset fires damage) */
    st->dirty_rows = (uint8_t *)calloc(rows, 1);
    st->any_damage = 0;

    /* Scrollback */
    scrollback_init(&st->scrollback, JVT_DEFAULT_SCROLLBACK);

    /* Text buffer (reusable) */
    st->text_buf_size = cols * 4 + 16;
    st->text_buf = (char *)malloc(st->text_buf_size);

    /* Set up screen callbacks before enabling screen */
    vterm_screen_set_callbacks(st->screen, &screen_cbs, st);
    vterm_screen_enable_altscreen(st->screen, 1);
    vterm_screen_enable_reflow(st->screen, 1);

    /* Use ROW-level damage merging for our batched update strategy */
    vterm_screen_set_damage_merge(st->screen, VTERM_DAMAGE_ROW);

    vterm_screen_reset(st->screen, 1);

    return st;
}

void jvt_free(void *handle) {
    JvtState *st = (JvtState *)handle;
    if (!st) return;
    scrollback_free(&st->scrollback);
    free(st->dirty_rows);
    free(st->text_buf);
    if (st->vt) vterm_free(st->vt);
    free(st);
}

void jvt_write(void *handle, const char *data, int len) {
    JvtState *st = (JvtState *)handle;
    if (!st || !data || len <= 0) return;
    vterm_input_write(st->vt, data, (size_t)len);
    vterm_screen_flush_damage(st->screen);
}

void jvt_resize(void *handle, int rows, int cols) {
    JvtState *st = (JvtState *)handle;
    if (!st || rows <= 0 || cols <= 0) return;

    vterm_set_size(st->vt, rows, cols);

    /* Reallocate dirty row tracking */
    free(st->dirty_rows);
    st->dirty_rows = (uint8_t *)calloc(rows, 1);
    /* Mark all rows dirty after resize */
    memset(st->dirty_rows, 1, rows);
    st->any_damage = 1;

    st->rows = rows;
    st->cols = cols;

    /* Resize text buffer */
    free(st->text_buf);
    st->text_buf_size = cols * 4 + 16;
    st->text_buf = (char *)malloc(st->text_buf_size);
}

/*
 * Get UTF-8 text for a single row.
 * Returns number of bytes written (not including NUL), or -1 on error.
 * The output is NUL-terminated.
 */
int jvt_get_row_text(void *handle, int row, char *buf, int buflen) {
    JvtState *st = (JvtState *)handle;
    if (!st || row < 0 || row >= st->rows || !buf || buflen <= 0) return -1;

    VTermRect rect = { .start_row = row, .end_row = row + 1,
                       .start_col = 0,   .end_col = st->cols };
    size_t n = vterm_screen_get_text(st->screen, buf, (size_t)buflen - 1, rect);
    buf[n] = '\0';

    /* Trim trailing spaces */
    while (n > 0 && buf[n - 1] == ' ') {
        n--;
        buf[n] = '\0';
    }
    return (int)n;
}

/*
 * Get text for a range of rows (start_row inclusive, end_row exclusive).
 * Rows are separated by newlines. Trailing spaces per row are trimmed.
 * Returns bytes written (not including NUL).
 */
int jvt_get_text(void *handle, char *buf, int buflen, int start_row, int end_row) {
    JvtState *st = (JvtState *)handle;
    if (!st || !buf || buflen <= 0) return -1;
    if (start_row < 0) start_row = 0;
    if (end_row > st->rows) end_row = st->rows;

    /* Temp buffer for single row */
    int row_buf_size = st->cols * 4 + 4;
    char *row_buf = st->text_buf;
    if (row_buf_size > st->text_buf_size) {
        row_buf = (char *)malloc(row_buf_size);
    }

    /* Find last non-empty row (trim trailing blank rows like old vtscreen) */
    int last_nonempty = start_row - 1;
    for (int r = end_row - 1; r >= start_row; r--) {
        VTermRect rect = { .start_row = r, .end_row = r + 1,
                           .start_col = 0, .end_col = st->cols };
        size_t n = vterm_screen_get_text(st->screen, row_buf, (size_t)row_buf_size - 1, rect);
        /* Trim trailing spaces */
        while (n > 0 && row_buf[n - 1] == ' ') n--;
        if (n > 0) {
            last_nonempty = r;
            break;
        }
    }

    if (last_nonempty < start_row) {
        /* All rows are empty */
        buf[0] = '\0';
        if (row_buf != st->text_buf) free(row_buf);
        return 0;
    }

    int pos = 0;
    for (int r = start_row; r <= last_nonempty; r++) {
        if (r > start_row && pos < buflen - 1) {
            buf[pos++] = '\n';
        }
        VTermRect rect = { .start_row = r, .end_row = r + 1,
                           .start_col = 0, .end_col = st->cols };
        size_t n = vterm_screen_get_text(st->screen, row_buf, (size_t)row_buf_size - 1, rect);
        row_buf[n] = '\0';
        /* Trim trailing spaces */
        while (n > 0 && row_buf[n - 1] == ' ') n--;

        int copy = (int)n;
        if (pos + copy >= buflen) copy = buflen - pos - 1;
        if (copy > 0) {
            memcpy(buf + pos, row_buf, copy);
            pos += copy;
        }
    }

    if (row_buf != st->text_buf) free(row_buf);
    buf[pos] = '\0';
    return pos;
}

int jvt_is_altscreen(void *handle) {
    JvtState *st = (JvtState *)handle;
    return st ? st->is_altscreen : 0;
}

int jvt_get_rows(void *handle) {
    JvtState *st = (JvtState *)handle;
    return st ? st->rows : 0;
}

int jvt_get_cols(void *handle) {
    JvtState *st = (JvtState *)handle;
    return st ? st->cols : 0;
}

int jvt_get_cursor_row(void *handle) {
    JvtState *st = (JvtState *)handle;
    if (!st) return 0;
    VTermPos pos;
    VTermState *state = vterm_obtain_state(st->vt);
    vterm_state_get_cursorpos(state, &pos);
    return pos.row;
}

int jvt_get_cursor_col(void *handle) {
    JvtState *st = (JvtState *)handle;
    if (!st) return 0;
    VTermPos pos;
    VTermState *state = vterm_obtain_state(st->vt);
    vterm_state_get_cursorpos(state, &pos);
    return pos.col;
}

/* ============================================================
 * Damage tracking
 * ============================================================ */

/*
 * Check if any row is dirty since last call to jvt_clear_damage().
 */
int jvt_has_damage(void *handle) {
    JvtState *st = (JvtState *)handle;
    return st ? st->any_damage : 0;
}

/*
 * Check if a specific row is dirty.
 */
int jvt_row_dirty(void *handle, int row) {
    JvtState *st = (JvtState *)handle;
    if (!st || row < 0 || row >= st->rows) return 0;
    return st->dirty_rows[row];
}

/*
 * Clear all damage flags.
 */
void jvt_clear_damage(void *handle) {
    JvtState *st = (JvtState *)handle;
    if (!st) return;
    memset(st->dirty_rows, 0, st->rows);
    st->any_damage = 0;
}

/*
 * Mark all rows as dirty (e.g., after resize or for initial render).
 */
void jvt_mark_all_dirty(void *handle) {
    JvtState *st = (JvtState *)handle;
    if (!st) return;
    memset(st->dirty_rows, 1, st->rows);
    st->any_damage = 1;
}

/* ============================================================
 * Per-cell color & attribute queries
 * ============================================================ */

/*
 * Get foreground color for a cell as packed 0x00RRGGBB.
 * Returns -1 for default fg.
 */
int jvt_get_cell_fg(void *handle, int row, int col) {
    JvtState *st = (JvtState *)handle;
    if (!st || row < 0 || row >= st->rows || col < 0 || col >= st->cols)
        return -1;

    VTermPos pos = { .row = row, .col = col };
    VTermScreenCell cell;
    vterm_screen_get_cell(st->screen, pos, &cell);

    if (VTERM_COLOR_IS_DEFAULT_FG(&cell.fg)) return -1;
    if (VTERM_COLOR_IS_INDEXED(&cell.fg)) {
        vterm_screen_convert_color_to_rgb(st->screen, &cell.fg);
    }
    return (cell.fg.rgb.red << 16) | (cell.fg.rgb.green << 8) | cell.fg.rgb.blue;
}

/*
 * Get background color for a cell as packed 0x00RRGGBB.
 * Returns -1 for default bg.
 */
int jvt_get_cell_bg(void *handle, int row, int col) {
    JvtState *st = (JvtState *)handle;
    if (!st || row < 0 || row >= st->rows || col < 0 || col >= st->cols)
        return -1;

    VTermPos pos = { .row = row, .col = col };
    VTermScreenCell cell;
    vterm_screen_get_cell(st->screen, pos, &cell);

    if (VTERM_COLOR_IS_DEFAULT_BG(&cell.bg)) return -1;
    if (VTERM_COLOR_IS_INDEXED(&cell.bg)) {
        vterm_screen_convert_color_to_rgb(st->screen, &cell.bg);
    }
    return (cell.bg.rgb.red << 16) | (cell.bg.rgb.green << 8) | cell.bg.rgb.blue;
}

/*
 * Get cell attributes as packed bits:
 *   bit 0: bold
 *   bit 1: underline (any type)
 *   bit 2: italic
 *   bit 3: blink
 *   bit 4: reverse
 *   bit 5: strike
 *   bit 6: conceal
 */
int jvt_get_cell_attrs(void *handle, int row, int col) {
    JvtState *st = (JvtState *)handle;
    if (!st || row < 0 || row >= st->rows || col < 0 || col >= st->cols)
        return 0;

    VTermPos pos = { .row = row, .col = col };
    VTermScreenCell cell;
    vterm_screen_get_cell(st->screen, pos, &cell);

    int attrs = 0;
    if (cell.attrs.bold)      attrs |= (1 << 0);
    if (cell.attrs.underline) attrs |= (1 << 1);
    if (cell.attrs.italic)    attrs |= (1 << 2);
    if (cell.attrs.blink)     attrs |= (1 << 3);
    if (cell.attrs.reverse)   attrs |= (1 << 4);
    if (cell.attrs.strike)    attrs |= (1 << 5);
    if (cell.attrs.conceal)   attrs |= (1 << 6);
    return attrs;
}

/* ============================================================
 * Scrollback access
 * ============================================================ */

int jvt_scrollback_len(void *handle) {
    JvtState *st = (JvtState *)handle;
    return st ? st->scrollback.count : 0;
}

/*
 * Get scrollback line by index (0 = most recent).
 * Returns bytes written (not including NUL), or -1 on error.
 */
int jvt_scrollback_line(void *handle, int idx, char *buf, int buflen) {
    JvtState *st = (JvtState *)handle;
    if (!st || !buf || buflen <= 0) return -1;

    JvtScrollLine *line = scrollback_get(&st->scrollback, idx);
    if (!line || !line->text) {
        buf[0] = '\0';
        return 0;
    }

    int copy = line->text_len < buflen - 1 ? line->text_len : buflen - 1;
    memcpy(buf, line->text, copy);
    buf[copy] = '\0';
    return copy;
}

void jvt_scrollback_clear(void *handle) {
    JvtState *st = (JvtState *)handle;
    if (!st) return;
    /* Free all lines and reset */
    scrollback_free(&st->scrollback);
    scrollback_init(&st->scrollback, JVT_DEFAULT_SCROLLBACK);
}

int jvt_scrollback_set_max(void *handle, int max_lines) {
    JvtState *st = (JvtState *)handle;
    if (!st || max_lines <= 0) return -1;

    /* Create new scrollback and copy existing lines */
    JvtScrollback new_sb;
    scrollback_init(&new_sb, max_lines);

    /* Copy from oldest to newest */
    int start = st->scrollback.count > max_lines ? st->scrollback.count - max_lines : 0;
    for (int i = st->scrollback.count - 1 - start; i >= 0; i--) {
        JvtScrollLine *line = scrollback_get(&st->scrollback, i);
        if (line && line->text) {
            scrollback_push(&new_sb, line->text, line->text_len);
        }
    }

    scrollback_free(&st->scrollback);
    st->scrollback = new_sb;
    return 0;
}
