/* qt_chez_shim.c — Deferred callback bridge for Chez Scheme + Qt SMP
 *
 * PROBLEM: Chez SMP GC uses stop-the-world rendezvous.  When
 * Sactivate_thread() registers the Qt event-loop pthread as a Chez VP,
 * the Qt thread never participates in GC safe-point protocol (it's in
 * poll()), causing permanent GC deadlock.
 *
 * SOLUTION: Qt callbacks never call Sactivate_thread().  Instead they
 * push events to a lock-free SPSC ring buffer.  The primordial Chez
 * thread drains the buffer via chez_qt_drain_pending_callbacks(),
 * calling the Scheme trampolines on a proper Chez thread.
 *
 * The ring buffer is single-producer (Qt event-loop thread) and
 * single-consumer (primordial Chez thread via master timer).
 */

#include "qt_shim.h"
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <stdatomic.h>

/* ---- Stored callback function pointers (set from Chez at init time) ---- */
static qt_callback_void   chez_void_callback   = NULL;
static qt_callback_string chez_string_callback  = NULL;
static qt_callback_int    chez_int_callback     = NULL;
static qt_callback_bool   chez_bool_callback    = NULL;

/* ==== Deferred Callback Queue (SPSC ring buffer) ==== */

#define CB_QUEUE_SIZE 8192  /* must be power of 2 */
#define CB_STRING_MAX 1024

enum cb_type { CB_VOID = 0, CB_STRING = 1, CB_INT = 2, CB_BOOL = 3 };

struct cb_entry {
    enum cb_type type;
    long id;
    int int_value;
    char str_value[CB_STRING_MAX];
};

static struct cb_entry cb_queue[CB_QUEUE_SIZE];
static _Atomic unsigned int cb_head = 0;  /* written by producer (Qt thread) */
static _Atomic unsigned int cb_tail = 0;  /* written by consumer (primordial) */

static inline void cb_push_void(long id) {
    unsigned int h = atomic_load_explicit(&cb_head, memory_order_relaxed);
    unsigned int next = (h + 1) & (CB_QUEUE_SIZE - 1);
    if (next == atomic_load_explicit(&cb_tail, memory_order_acquire))
        return;  /* queue full — drop event */
    cb_queue[h].type = CB_VOID;
    cb_queue[h].id = id;
    atomic_store_explicit(&cb_head, next, memory_order_release);
}

static inline void cb_push_string(long id, const char* s) {
    unsigned int h = atomic_load_explicit(&cb_head, memory_order_relaxed);
    unsigned int next = (h + 1) & (CB_QUEUE_SIZE - 1);
    if (next == atomic_load_explicit(&cb_tail, memory_order_acquire))
        return;
    cb_queue[h].type = CB_STRING;
    cb_queue[h].id = id;
    if (s) {
        strncpy(cb_queue[h].str_value, s, CB_STRING_MAX - 1);
        cb_queue[h].str_value[CB_STRING_MAX - 1] = '\0';
    } else {
        cb_queue[h].str_value[0] = '\0';
    }
    atomic_store_explicit(&cb_head, next, memory_order_release);
}

static inline void cb_push_int(long id, int v) {
    unsigned int h = atomic_load_explicit(&cb_head, memory_order_relaxed);
    unsigned int next = (h + 1) & (CB_QUEUE_SIZE - 1);
    if (next == atomic_load_explicit(&cb_tail, memory_order_acquire))
        return;
    cb_queue[h].type = CB_INT;
    cb_queue[h].id = id;
    cb_queue[h].int_value = v;
    atomic_store_explicit(&cb_head, next, memory_order_release);
}

static inline void cb_push_bool(long id, int v) {
    unsigned int h = atomic_load_explicit(&cb_head, memory_order_relaxed);
    unsigned int next = (h + 1) & (CB_QUEUE_SIZE - 1);
    if (next == atomic_load_explicit(&cb_tail, memory_order_acquire))
        return;
    cb_queue[h].type = CB_BOOL;
    cb_queue[h].id = id;
    cb_queue[h].int_value = v;
    atomic_store_explicit(&cb_head, next, memory_order_release);
}

/* ---- Deferred wrappers: push to queue instead of calling Scheme ---- */
static void deferred_void_callback(long id)              { cb_push_void(id); }
static void deferred_string_callback(long id, const char* s) { cb_push_string(id, s); }
static void deferred_int_callback(long id, int v)         { cb_push_int(id, v); }
static void deferred_bool_callback(long id, int v)        { cb_push_bool(id, v); }

/* ---- Drain function: called from primordial Chez thread ---- */
void chez_qt_drain_pending_callbacks(void) {
    unsigned int t = atomic_load_explicit(&cb_tail, memory_order_relaxed);
    unsigned int h = atomic_load_explicit(&cb_head, memory_order_acquire);
    while (t != h) {
        struct cb_entry *e = &cb_queue[t];
        switch (e->type) {
        case CB_VOID:
            if (chez_void_callback) chez_void_callback(e->id);
            break;
        case CB_STRING:
            if (chez_string_callback) chez_string_callback(e->id, e->str_value);
            break;
        case CB_INT:
            if (chez_int_callback) chez_int_callback(e->id, e->int_value);
            break;
        case CB_BOOL:
            if (chez_bool_callback) chez_bool_callback(e->id, e->int_value);
            break;
        }
        t = (t + 1) & (CB_QUEUE_SIZE - 1);
        atomic_store_explicit(&cb_tail, t, memory_order_release);
        /* re-read head in case more events arrived */
        h = atomic_load_explicit(&cb_head, memory_order_acquire);
    }
}

/* ---- Registration functions (called once from Chez at library load) ---- */
void chez_qt_set_void_callback(qt_callback_void cb)     { chez_void_callback = cb; }
void chez_qt_set_string_callback(qt_callback_string cb)  { chez_string_callback = cb; }
void chez_qt_set_int_callback(qt_callback_int cb)        { chez_int_callback = cb; }
void chez_qt_set_bool_callback(qt_callback_bool cb)      { chez_bool_callback = cb; }

/* ---- Application lifecycle ---- */
void* chez_qt_application_create(void) {
    return qt_application_create(0, NULL);
}

/* ---- Signal connection wrappers ---- */
/* Each wrapper inserts the deferred callback as the trampoline.
 * The Qt thread only writes to the ring buffer — never calls Scheme. */

/* Push Button */
void chez_qt_push_button_on_clicked(void* b, long callback_id) {
    if (chez_void_callback)
        qt_push_button_on_clicked(b, deferred_void_callback, callback_id);
}

/* Line Edit */
void chez_qt_line_edit_on_text_changed(void* e, long callback_id) {
    if (chez_string_callback)
        qt_line_edit_on_text_changed(e, deferred_string_callback, callback_id);
}
void chez_qt_line_edit_on_return_pressed(void* e, long callback_id) {
    if (chez_void_callback)
        qt_line_edit_on_return_pressed(e, deferred_void_callback, callback_id);
}

/* Check Box */
void chez_qt_check_box_on_toggled(void* c, long callback_id) {
    if (chez_bool_callback)
        qt_check_box_on_toggled(c, deferred_bool_callback, callback_id);
}

/* Combo Box */
void chez_qt_combo_box_on_current_index_changed(void* c, long callback_id) {
    if (chez_int_callback)
        qt_combo_box_on_current_index_changed(c, deferred_int_callback, callback_id);
}

/* Text Edit */
void chez_qt_text_edit_on_text_changed(void* e, long callback_id) {
    if (chez_void_callback)
        qt_text_edit_on_text_changed(e, deferred_void_callback, callback_id);
}

/* Spin Box */
void chez_qt_spin_box_on_value_changed(void* s, long callback_id) {
    if (chez_int_callback)
        qt_spin_box_on_value_changed(s, deferred_int_callback, callback_id);
}

/* Action */
void chez_qt_action_on_triggered(void* a, long callback_id) {
    if (chez_void_callback)
        qt_action_on_triggered(a, deferred_void_callback, callback_id);
}
void chez_qt_action_on_toggled(void* a, long callback_id) {
    if (chez_bool_callback)
        qt_action_on_toggled(a, deferred_bool_callback, callback_id);
}

/* List Widget */
void chez_qt_list_widget_on_current_row_changed(void* l, long callback_id) {
    if (chez_int_callback)
        qt_list_widget_on_current_row_changed(l, deferred_int_callback, callback_id);
}
void chez_qt_list_widget_on_item_double_clicked(void* l, long callback_id) {
    if (chez_int_callback)
        qt_list_widget_on_item_double_clicked(l, deferred_int_callback, callback_id);
}

/* Table Widget */
void chez_qt_table_widget_on_cell_clicked(void* t, long callback_id) {
    if (chez_void_callback)
        qt_table_widget_on_cell_clicked(t, deferred_void_callback, callback_id);
}

/* Tab Widget */
void chez_qt_tab_widget_on_current_changed(void* t, long callback_id) {
    if (chez_int_callback)
        qt_tab_widget_on_current_changed(t, deferred_int_callback, callback_id);
}

/* Slider */
void chez_qt_slider_on_value_changed(void* s, long callback_id) {
    if (chez_int_callback)
        qt_slider_on_value_changed(s, deferred_int_callback, callback_id);
}

/* Timer */
void chez_qt_timer_on_timeout(void* t, long callback_id) {
    if (chez_void_callback)
        qt_timer_on_timeout(t, deferred_void_callback, callback_id);
}
void chez_qt_timer_single_shot(int msec, long callback_id) {
    if (chez_void_callback)
        qt_timer_single_shot(msec, deferred_void_callback, callback_id);
}

/* Clipboard */
void chez_qt_clipboard_on_changed(void* app, long callback_id) {
    if (chez_void_callback)
        qt_clipboard_on_changed(app, deferred_void_callback, callback_id);
}

/* Tree Widget */
void chez_qt_tree_widget_on_current_item_changed(void* t, long callback_id) {
    if (chez_void_callback)
        qt_tree_widget_on_current_item_changed(t, deferred_void_callback, callback_id);
}
void chez_qt_tree_widget_on_item_double_clicked(void* t, long callback_id) {
    if (chez_void_callback)
        qt_tree_widget_on_item_double_clicked(t, deferred_void_callback, callback_id);
}
void chez_qt_tree_widget_on_item_expanded(void* t, long callback_id) {
    if (chez_void_callback)
        qt_tree_widget_on_item_expanded(t, deferred_void_callback, callback_id);
}
void chez_qt_tree_widget_on_item_collapsed(void* t, long callback_id) {
    if (chez_void_callback)
        qt_tree_widget_on_item_collapsed(t, deferred_void_callback, callback_id);
}

/* Keyboard Events */
void chez_qt_install_key_handler(void* w, long callback_id) {
    if (chez_void_callback)
        qt_widget_install_key_handler(w, deferred_void_callback, callback_id);
}
void chez_qt_install_key_handler_consuming(void* w, long callback_id) {
    if (chez_void_callback)
        qt_widget_install_key_handler_consuming(w, deferred_void_callback, callback_id);
}

/* Radio Button */
void chez_qt_radio_button_on_toggled(void* r, long callback_id) {
    if (chez_bool_callback)
        qt_radio_button_on_toggled(r, deferred_bool_callback, callback_id);
}

/* Button Group */
void chez_qt_button_group_on_clicked(void* g, long callback_id) {
    if (chez_int_callback)
        qt_button_group_on_id_clicked(g, deferred_int_callback, callback_id);
}

/* Group Box */
void chez_qt_group_box_on_toggled(void* g, long callback_id) {
    if (chez_bool_callback)
        qt_group_box_on_toggled(g, deferred_bool_callback, callback_id);
}

/* Stacked Widget */
void chez_qt_stacked_widget_on_current_changed(void* s, long callback_id) {
    if (chez_int_callback)
        qt_stacked_widget_on_current_changed(s, deferred_int_callback, callback_id);
}

/* System Tray */
void chez_qt_system_tray_icon_on_activated(void* t, long callback_id) {
    if (chez_int_callback)
        qt_system_tray_icon_on_activated(t, deferred_int_callback, callback_id);
}

/* Paint Widget */
void chez_qt_paint_widget_on_paint(void* w, long callback_id) {
    if (chez_void_callback)
        qt_paint_widget_on_paint(w, deferred_void_callback, callback_id);
}

/* Completer */
void chez_qt_completer_on_activated(void* c, long callback_id) {
    if (chez_string_callback)
        qt_completer_on_activated(c, deferred_string_callback, callback_id);
}

/* Double Spin Box — value comes as string */
void chez_qt_double_spin_box_on_value_changed(void* s, long callback_id) {
    if (chez_string_callback)
        qt_double_spin_box_on_value_changed(s, deferred_string_callback, callback_id);
}

/* Date Edit — date comes as string */
void chez_qt_date_edit_on_date_changed(void* d, long callback_id) {
    if (chez_string_callback)
        qt_date_edit_on_date_changed(d, deferred_string_callback, callback_id);
}

/* Time Edit — time comes as string */
void chez_qt_time_edit_on_time_changed(void* t, long callback_id) {
    if (chez_string_callback)
        qt_time_edit_on_time_changed(t, deferred_string_callback, callback_id);
}

/* Progress Dialog */
void chez_qt_progress_dialog_on_canceled(void* d, long callback_id) {
    if (chez_void_callback)
        qt_progress_dialog_on_canceled(d, deferred_void_callback, callback_id);
}

/* Shortcut */
void chez_qt_shortcut_on_activated(void* s, long callback_id) {
    if (chez_void_callback)
        qt_shortcut_on_activated(s, deferred_void_callback, callback_id);
}

/* Text Browser */
void chez_qt_text_browser_on_anchor_clicked(void* b, long callback_id) {
    if (chez_string_callback)
        qt_text_browser_on_anchor_clicked(b, deferred_string_callback, callback_id);
}

/* Button Box */
void chez_qt_button_box_on_accepted(void* b, long callback_id) {
    if (chez_void_callback)
        qt_button_box_on_accepted(b, deferred_void_callback, callback_id);
}
void chez_qt_button_box_on_rejected(void* b, long callback_id) {
    if (chez_void_callback)
        qt_button_box_on_rejected(b, deferred_void_callback, callback_id);
}
void chez_qt_button_box_on_clicked(void* b, long callback_id) {
    if (chez_void_callback)
        qt_button_box_on_clicked(b, deferred_void_callback, callback_id);
}

/* Calendar */
void chez_qt_calendar_on_selection_changed(void* c, long callback_id) {
    if (chez_void_callback)
        qt_calendar_on_selection_changed(c, deferred_void_callback, callback_id);
}
void chez_qt_calendar_on_clicked(void* c, long callback_id) {
    if (chez_string_callback)
        qt_calendar_on_clicked(c, deferred_string_callback, callback_id);
}

/* View signals */
void chez_qt_view_on_clicked(void* v, long callback_id) {
    if (chez_void_callback)
        qt_view_on_clicked(v, deferred_void_callback, callback_id);
}
void chez_qt_view_on_double_clicked(void* v, long callback_id) {
    if (chez_void_callback)
        qt_view_on_double_clicked(v, deferred_void_callback, callback_id);
}
void chez_qt_view_on_activated(void* v, long callback_id) {
    if (chez_void_callback)
        qt_view_on_activated(v, deferred_void_callback, callback_id);
}
void chez_qt_view_on_selection_changed(void* v, long callback_id) {
    if (chez_void_callback)
        qt_view_on_selection_changed(v, deferred_void_callback, callback_id);
}

/* Plain Text Edit */
void chez_qt_plain_text_edit_on_text_changed(void* e, long callback_id) {
    if (chez_void_callback)
        qt_plain_text_edit_on_text_changed(e, deferred_void_callback, callback_id);
}

/* Tool Button */
void chez_qt_tool_button_on_clicked(void* b, long callback_id) {
    if (chez_void_callback)
        qt_tool_button_on_clicked(b, deferred_void_callback, callback_id);
}

/* Process */
void chez_qt_process_on_finished(void* p, long callback_id) {
    if (chez_int_callback)
        qt_process_on_finished(p, deferred_int_callback, callback_id);
}
void chez_qt_process_on_ready_read(void* p, long callback_id) {
    if (chez_void_callback)
        qt_process_on_ready_read(p, deferred_void_callback, callback_id);
}

/* Wizard */
void chez_qt_wizard_on_current_changed(void* w, long callback_id) {
    if (chez_int_callback)
        qt_wizard_on_current_changed(w, deferred_int_callback, callback_id);
}

/* MDI Area */
void chez_qt_mdi_area_on_sub_window_activated(void* a, long callback_id) {
    if (chez_void_callback)
        qt_mdi_area_on_sub_window_activated(a, deferred_void_callback, callback_id);
}

/* Dial */
void chez_qt_dial_on_value_changed(void* d, long callback_id) {
    if (chez_int_callback)
        qt_dial_on_value_changed(d, deferred_int_callback, callback_id);
}

/* Tool Box */
void chez_qt_tool_box_on_current_changed(void* t, long callback_id) {
    if (chez_int_callback)
        qt_tool_box_on_current_changed(t, deferred_int_callback, callback_id);
}

/* QScintilla (conditional) */
#ifdef QT_SCINTILLA_AVAILABLE
void chez_qt_scintilla_on_text_changed(void* s, long callback_id) {
    if (chez_void_callback)
        qt_scintilla_on_text_changed(s, deferred_void_callback, callback_id);
}
void chez_qt_scintilla_on_char_added(void* s, long callback_id) {
    if (chez_int_callback)
        qt_scintilla_on_char_added(s, deferred_int_callback, callback_id);
}
void chez_qt_scintilla_on_save_point_reached(void* s, long callback_id) {
    if (chez_void_callback)
        qt_scintilla_on_save_point_reached(s, deferred_void_callback, callback_id);
}
void chez_qt_scintilla_on_save_point_left(void* s, long callback_id) {
    if (chez_void_callback)
        qt_scintilla_on_save_point_left(s, deferred_void_callback, callback_id);
}
void chez_qt_scintilla_on_margin_clicked(void* s, long callback_id) {
    if (chez_int_callback)
        qt_scintilla_on_margin_clicked(s, deferred_int_callback, callback_id);
}
void chez_qt_scintilla_on_modified(void* s, long callback_id) {
    if (chez_void_callback)
        qt_scintilla_on_modified(s, (qt_callback_int)deferred_void_callback, callback_id);
}
#endif
