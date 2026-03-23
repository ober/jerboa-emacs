/* chez_scintilla_stubs.c — No-op stubs for static Qt builds
 *
 * The Qt frontend uses QScintilla, not the TUI Scintilla+termbox backend.
 * However, the Chez Scheme code has foreign-procedure definitions referencing
 * these C symbols. For the static binary to link, all symbols must be present
 * (even though they are never called at runtime).
 */

#include <stdint.h>

/* ================================================================
   Scintilla instance lifecycle
   ================================================================ */
void *chez_scintilla_new(void) { return (void*)0; }
void  chez_scintilla_delete(void *handle) { (void)handle; }

/* ================================================================
   Message passing
   ================================================================ */
long chez_scintilla_send_message(void *handle, unsigned int msg,
                                 unsigned long wparam, long lparam) {
    (void)handle; (void)msg; (void)wparam; (void)lparam;
    return 0;
}

long chez_scintilla_send_message_string(void *handle, unsigned int msg,
                                         unsigned long wparam, const char *s) {
    (void)handle; (void)msg; (void)wparam; (void)s;
    return 0;
}

const char *chez_scintilla_receive_string(void *handle, unsigned int msg,
                                           unsigned long wparam) {
    (void)handle; (void)msg; (void)wparam;
    return "";
}

long chez_scintilla_set_property(void *handle, unsigned int msg,
                                  const char *key, const char *val) {
    (void)handle; (void)msg; (void)key; (void)val;
    return 0;
}

/* ================================================================
   Input
   ================================================================ */
void chez_scintilla_send_key(void *handle, int key,
                              int shift, int ctrl, int alt) {
    (void)handle; (void)key; (void)shift; (void)ctrl; (void)alt;
}

int chez_scintilla_send_mouse(void *handle, int event, int button,
                               int x, int y, int ctrl) {
    (void)handle; (void)event; (void)button;
    (void)x; (void)y; (void)ctrl;
    return 0;
}

/* ================================================================
   Display
   ================================================================ */
void chez_scintilla_refresh(void *handle) { (void)handle; }
void chez_scintilla_resize(void *handle, int width, int height) {
    (void)handle; (void)width; (void)height;
}
void chez_scintilla_move(void *handle, int x, int y) {
    (void)handle; (void)x; (void)y;
}

/* ================================================================
   Clipboard & Lexer
   ================================================================ */
const char *chez_scintilla_get_clipboard(void *handle) {
    (void)handle;
    return "";
}

void chez_scintilla_set_lexer_language(void *handle, const char *lang) {
    (void)handle; (void)lang;
}

/* ================================================================
   Notification queue
   ================================================================ */
int chez_scintilla_drain_one(void *handle) {
    (void)handle;
    return 0;
}

/* ================================================================
   Notification field accessors (all return zero/empty)
   ================================================================ */
int         chez_scn_code(void)              { return 0; }
long        chez_scn_position(void)          { return 0; }
int         chez_scn_ch(void)                { return 0; }
int         chez_scn_modifiers(void)         { return 0; }
int         chez_scn_modification_type(void) { return 0; }
const char *chez_scn_text(void)              { return ""; }
long        chez_scn_length(void)            { return 0; }
long        chez_scn_lines_added(void)       { return 0; }
int         chez_scn_message(void)           { return 0; }
long        chez_scn_line(void)              { return 0; }
int         chez_scn_fold_level_now(void)    { return 0; }
int         chez_scn_fold_level_prev(void)   { return 0; }
int         chez_scn_margin(void)            { return 0; }
int         chez_scn_list_type(void)         { return 0; }
int         chez_scn_x(void)                 { return 0; }
int         chez_scn_y(void)                 { return 0; }
int         chez_scn_token(void)             { return 0; }
int         chez_scn_updated(void)           { return 0; }

/* ================================================================
   Termbox stubs (TUI terminal library — unused in Qt)
   ================================================================ */
int  chez_tb_init(void)           { return -1; }
void chez_tb_shutdown(void)       { }
int  chez_tb_width(void)          { return 0; }
int  chez_tb_height(void)         { return 0; }
void chez_tb_clear(void)          { }
void chez_tb_present(void)        { }
void chez_tb_set_cursor(int x, int y) { (void)x; (void)y; }

int chez_tb_poll_event(void)          { return 0; }
int chez_tb_peek_event(int timeout_ms) { (void)timeout_ms; return 0; }

/* ================================================================
   Termbox event field accessors
   ================================================================ */
int          chez_tb_event_type(void) { return 0; }
int          chez_tb_event_mod(void)  { return 0; }
int          chez_tb_event_key(void)  { return 0; }
unsigned int chez_tb_event_ch(void)   { return 0; }
int          chez_tb_event_w(void)    { return 0; }
int          chez_tb_event_h(void)    { return 0; }
int          chez_tb_event_x(void)    { return 0; }
int          chez_tb_event_y(void)    { return 0; }

/* ================================================================
   Termbox extended operations
   ================================================================ */
void chez_tb_change_cell(int x, int y, uint32_t ch, uint32_t fg, uint32_t bg) {
    (void)x; (void)y; (void)ch; (void)fg; (void)bg;
}

void chez_tb_set_clear_attributes(uint32_t fg, uint32_t bg) {
    (void)fg; (void)bg;
}

int chez_tb_select_input_mode(int mode) { (void)mode; return 0; }
int chez_tb_select_output_mode(int mode) { (void)mode; return 0; }

void chez_tb_print_string(int x, int y, uint32_t fg, uint32_t bg, const char *str) {
    (void)x; (void)y; (void)fg; (void)bg; (void)str;
}
