#ifndef QT_SHIM_H
#define QT_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

/* --- Opaque handle types --- */
typedef void* qt_application_t;
typedef void* qt_widget_t;
typedef void* qt_main_window_t;
typedef void* qt_layout_t;
typedef void* qt_label_t;
typedef void* qt_push_button_t;

/* --- Callback signatures --- */
typedef void (*qt_callback_void)(long callback_id);
typedef void (*qt_callback_string)(long callback_id, const char* value);
typedef void (*qt_callback_int)(long callback_id, int value);
typedef void (*qt_callback_bool)(long callback_id, int value);

/* --- Application lifecycle --- */
qt_application_t qt_application_create(int argc, char** argv);
int              qt_application_exec(qt_application_t app);
void             qt_application_quit(qt_application_t app);
void             qt_application_process_events(qt_application_t app);
void             qt_application_destroy(qt_application_t app);

/* --- Widget base (applies to all widget types) --- */
qt_widget_t qt_widget_create(qt_widget_t parent);
void qt_widget_show(qt_widget_t w);
void qt_widget_hide(qt_widget_t w);
void qt_widget_close(qt_widget_t w);
void qt_widget_set_enabled(qt_widget_t w, int enabled);
int  qt_widget_is_enabled(qt_widget_t w);
void qt_widget_set_visible(qt_widget_t w, int visible);
int  qt_widget_is_visible(qt_widget_t w);
void qt_widget_set_fixed_size(qt_widget_t w, int width, int height);
void qt_widget_set_minimum_size(qt_widget_t w, int width, int height);
void qt_widget_set_maximum_size(qt_widget_t w, int width, int height);
void qt_widget_set_minimum_width(qt_widget_t w, int width);
void qt_widget_set_minimum_height(qt_widget_t w, int height);
void qt_widget_set_maximum_width(qt_widget_t w, int width);
void qt_widget_set_maximum_height(qt_widget_t w, int height);
void qt_widget_set_cursor(qt_widget_t w, int shape);
void qt_widget_unset_cursor(qt_widget_t w);
void qt_widget_resize(qt_widget_t w, int width, int height);
void qt_widget_set_style_sheet(qt_widget_t w, const char* css);
void qt_widget_set_tooltip(qt_widget_t w, const char* text);
void qt_widget_set_font_size(qt_widget_t w, int size);
void qt_widget_destroy(qt_widget_t w);

/* --- Main Window --- */
qt_main_window_t qt_main_window_create(qt_widget_t parent);
void qt_main_window_set_title(qt_main_window_t w, const char* title);
void qt_main_window_set_central_widget(qt_main_window_t w, qt_widget_t child);

/* --- Layouts --- */
qt_layout_t qt_vbox_layout_create(qt_widget_t parent);
qt_layout_t qt_hbox_layout_create(qt_widget_t parent);
void qt_layout_add_widget(qt_layout_t layout, qt_widget_t widget);
void qt_layout_add_stretch(qt_layout_t layout, int stretch);
void qt_layout_set_spacing(qt_layout_t layout, int spacing);
void qt_layout_set_margins(qt_layout_t layout, int left, int top,
                           int right, int bottom);

/* --- Labels --- */
qt_label_t qt_label_create(const char* text, qt_widget_t parent);
void qt_label_set_text(qt_label_t l, const char* text);
const char* qt_label_text(qt_label_t l);
void qt_label_set_alignment(qt_label_t l, int alignment);
void qt_label_set_word_wrap(qt_label_t l, int wrap);

/* --- Push Button --- */
qt_push_button_t qt_push_button_create(const char* text, qt_widget_t parent);
void qt_push_button_set_text(qt_push_button_t b, const char* text);
const char* qt_push_button_text(qt_push_button_t b);
void qt_push_button_on_clicked(qt_push_button_t b,
                               qt_callback_void callback,
                               long callback_id);

/* ========== Phase 2 widgets ========== */

typedef void* qt_line_edit_t;
typedef void* qt_check_box_t;
typedef void* qt_combo_box_t;
typedef void* qt_text_edit_t;
typedef void* qt_spin_box_t;
typedef void* qt_dialog_t;

/* --- Line Edit --- */
qt_line_edit_t qt_line_edit_create(qt_widget_t parent);
void        qt_line_edit_set_text(qt_line_edit_t e, const char* text);
const char* qt_line_edit_text(qt_line_edit_t e);
void        qt_line_edit_set_placeholder(qt_line_edit_t e, const char* text);
void        qt_line_edit_set_read_only(qt_line_edit_t e, int read_only);
void        qt_line_edit_set_echo_mode(qt_line_edit_t e, int mode);
void        qt_line_edit_on_text_changed(qt_line_edit_t e,
                                         qt_callback_string callback,
                                         long callback_id);
void        qt_line_edit_on_return_pressed(qt_line_edit_t e,
                                           qt_callback_void callback,
                                           long callback_id);

/* --- Check Box --- */
qt_check_box_t qt_check_box_create(const char* text, qt_widget_t parent);
void qt_check_box_set_text(qt_check_box_t c, const char* text);
void qt_check_box_set_checked(qt_check_box_t c, int checked);
int  qt_check_box_is_checked(qt_check_box_t c);
void qt_check_box_on_toggled(qt_check_box_t c,
                              qt_callback_bool callback,
                              long callback_id);

/* --- Combo Box --- */
qt_combo_box_t qt_combo_box_create(qt_widget_t parent);
void        qt_combo_box_add_item(qt_combo_box_t c, const char* text);
void        qt_combo_box_set_current_index(qt_combo_box_t c, int index);
int         qt_combo_box_current_index(qt_combo_box_t c);
const char* qt_combo_box_current_text(qt_combo_box_t c);
int         qt_combo_box_count(qt_combo_box_t c);
void        qt_combo_box_clear(qt_combo_box_t c);
void        qt_combo_box_on_current_index_changed(qt_combo_box_t c,
                                                   qt_callback_int callback,
                                                   long callback_id);

/* --- Text Edit --- */
qt_text_edit_t qt_text_edit_create(qt_widget_t parent);
void        qt_text_edit_set_text(qt_text_edit_t e, const char* text);
const char* qt_text_edit_text(qt_text_edit_t e);
void        qt_text_edit_set_placeholder(qt_text_edit_t e, const char* text);
void        qt_text_edit_set_read_only(qt_text_edit_t e, int read_only);
void        qt_text_edit_append(qt_text_edit_t e, const char* text);
void        qt_text_edit_clear(qt_text_edit_t e);
void        qt_text_edit_scroll_to_bottom(qt_text_edit_t e);
const char* qt_text_edit_html(qt_text_edit_t e);
void        qt_text_edit_on_text_changed(qt_text_edit_t e,
                                          qt_callback_void callback,
                                          long callback_id);

/* --- Spin Box --- */
qt_spin_box_t qt_spin_box_create(qt_widget_t parent);
void qt_spin_box_set_value(qt_spin_box_t s, int value);
int  qt_spin_box_value(qt_spin_box_t s);
void qt_spin_box_set_range(qt_spin_box_t s, int minimum, int maximum);
void qt_spin_box_set_single_step(qt_spin_box_t s, int step);
void qt_spin_box_set_prefix(qt_spin_box_t s, const char* prefix);
void qt_spin_box_set_suffix(qt_spin_box_t s, const char* suffix);
void qt_spin_box_on_value_changed(qt_spin_box_t s,
                                   qt_callback_int callback,
                                   long callback_id);

/* --- Dialog --- */
qt_dialog_t qt_dialog_create(qt_widget_t parent);
int  qt_dialog_exec(qt_dialog_t d);
void qt_dialog_accept(qt_dialog_t d);
void qt_dialog_reject(qt_dialog_t d);
void qt_dialog_set_title(qt_dialog_t d, const char* title);

/* --- Message Box (static convenience) --- */
int qt_message_box_information(qt_widget_t parent, const char* title, const char* text);
int qt_message_box_warning(qt_widget_t parent, const char* title, const char* text);
int qt_message_box_question(qt_widget_t parent, const char* title, const char* text);
int qt_message_box_critical(qt_widget_t parent, const char* title, const char* text);

/* --- File Dialog (static convenience) --- */
const char* qt_file_dialog_open_file(qt_widget_t parent, const char* caption,
                                     const char* dir, const char* filter);
const char* qt_file_dialog_save_file(qt_widget_t parent, const char* caption,
                                     const char* dir, const char* filter);
const char* qt_file_dialog_open_directory(qt_widget_t parent, const char* caption,
                                          const char* dir);

/* ========== Phase 3: Menus, Actions, Toolbars ========== */

typedef void* qt_menu_bar_t;
typedef void* qt_menu_t;
typedef void* qt_action_t;
typedef void* qt_toolbar_t;

/* --- Menu Bar --- */
qt_menu_bar_t qt_main_window_menu_bar(qt_main_window_t w);

/* --- Menu --- */
qt_menu_t  qt_menu_bar_add_menu(qt_menu_bar_t bar, const char* title);
qt_menu_t  qt_menu_add_menu(qt_menu_t menu, const char* title);
void       qt_menu_add_action(qt_menu_t menu, qt_action_t action);
void       qt_menu_add_separator(qt_menu_t menu);

/* --- Action --- */
qt_action_t qt_action_create(const char* text, qt_widget_t parent);
void        qt_action_set_text(qt_action_t a, const char* text);
const char* qt_action_text(qt_action_t a);
void        qt_action_set_shortcut(qt_action_t a, const char* shortcut);
void        qt_action_set_enabled(qt_action_t a, int enabled);
int         qt_action_is_enabled(qt_action_t a);
void        qt_action_set_checkable(qt_action_t a, int checkable);
int         qt_action_is_checkable(qt_action_t a);
void        qt_action_set_checked(qt_action_t a, int checked);
int         qt_action_is_checked(qt_action_t a);
void        qt_action_set_tooltip(qt_action_t a, const char* text);
void        qt_action_set_status_tip(qt_action_t a, const char* text);
void        qt_action_on_triggered(qt_action_t a,
                                   qt_callback_void callback,
                                   long callback_id);
void        qt_action_on_toggled(qt_action_t a,
                                 qt_callback_bool callback,
                                 long callback_id);

/* --- Toolbar --- */
qt_toolbar_t qt_toolbar_create(const char* title, qt_widget_t parent);
void         qt_main_window_add_toolbar(qt_main_window_t w, qt_toolbar_t tb);
void         qt_toolbar_add_action(qt_toolbar_t tb, qt_action_t action);
void         qt_toolbar_add_separator(qt_toolbar_t tb);
void         qt_toolbar_add_widget(qt_toolbar_t tb, qt_widget_t w);
void         qt_toolbar_set_movable(qt_toolbar_t tb, int movable);
void         qt_toolbar_set_icon_size(qt_toolbar_t tb, int width, int height);

/* --- Status Bar --- */
void         qt_main_window_set_status_bar_text(qt_main_window_t w, const char* text);

/* ========== Phase 5: Grid Layout, Timer, Clipboard, Tree ========== */

/* --- Grid Layout --- */
qt_layout_t qt_grid_layout_create(qt_widget_t parent);
void qt_grid_layout_add_widget(qt_layout_t layout, qt_widget_t widget,
                               int row, int col, int row_span, int col_span);
void qt_grid_layout_set_row_stretch(qt_layout_t layout, int row, int stretch);
void qt_grid_layout_set_column_stretch(qt_layout_t layout, int col, int stretch);
void qt_grid_layout_set_row_minimum_height(qt_layout_t layout, int row, int height);
void qt_grid_layout_set_column_minimum_width(qt_layout_t layout, int col, int width);

/* --- Timer --- */
typedef void* qt_timer_t;

qt_timer_t qt_timer_create(void);
void       qt_timer_start(qt_timer_t t, int msec);
void       qt_timer_stop(qt_timer_t t);
void       qt_timer_set_single_shot(qt_timer_t t, int single_shot);
int        qt_timer_is_active(qt_timer_t t);
int        qt_timer_interval(qt_timer_t t);
void       qt_timer_set_interval(qt_timer_t t, int msec);
void       qt_timer_on_timeout(qt_timer_t t,
                               qt_callback_void callback,
                               long callback_id);
void       qt_timer_single_shot(int msec,
                                qt_callback_void callback,
                                long callback_id);
void       qt_timer_destroy(qt_timer_t t);

/* --- Clipboard --- */
const char* qt_clipboard_text(qt_application_t app);
void        qt_clipboard_set_text(qt_application_t app, const char* text);
void        qt_clipboard_on_changed(qt_application_t app,
                                    qt_callback_void callback,
                                    long callback_id);

/* --- Tree Widget --- */
typedef void* qt_tree_widget_t;
typedef void* qt_tree_item_t;

qt_tree_widget_t qt_tree_widget_create(qt_widget_t parent);
void        qt_tree_widget_set_column_count(qt_tree_widget_t t, int count);
int         qt_tree_widget_column_count(qt_tree_widget_t t);
void        qt_tree_widget_set_header_label(qt_tree_widget_t t, const char* label);
void        qt_tree_widget_set_header_item_text(qt_tree_widget_t t,
                                                 int col, const char* text);
void        qt_tree_widget_add_top_level_item(qt_tree_widget_t t, qt_tree_item_t item);
int         qt_tree_widget_top_level_item_count(qt_tree_widget_t t);
qt_tree_item_t qt_tree_widget_top_level_item(qt_tree_widget_t t, int index);
qt_tree_item_t qt_tree_widget_current_item(qt_tree_widget_t t);
void        qt_tree_widget_set_current_item(qt_tree_widget_t t, qt_tree_item_t item);
void        qt_tree_widget_expand_item(qt_tree_widget_t t, qt_tree_item_t item);
void        qt_tree_widget_collapse_item(qt_tree_widget_t t, qt_tree_item_t item);
void        qt_tree_widget_expand_all(qt_tree_widget_t t);
void        qt_tree_widget_collapse_all(qt_tree_widget_t t);
void        qt_tree_widget_clear(qt_tree_widget_t t);
void        qt_tree_widget_on_current_item_changed(qt_tree_widget_t t,
                                                    qt_callback_void callback,
                                                    long callback_id);
void        qt_tree_widget_on_item_double_clicked(qt_tree_widget_t t,
                                                   qt_callback_void callback,
                                                   long callback_id);
void        qt_tree_widget_on_item_expanded(qt_tree_widget_t t,
                                             qt_callback_void callback,
                                             long callback_id);
void        qt_tree_widget_on_item_collapsed(qt_tree_widget_t t,
                                              qt_callback_void callback,
                                              long callback_id);

/* --- Tree Widget Item --- */
qt_tree_item_t qt_tree_item_create(const char* text);
void        qt_tree_item_set_text(qt_tree_item_t item, int col, const char* text);
const char* qt_tree_item_text(qt_tree_item_t item, int col);
void        qt_tree_item_add_child(qt_tree_item_t parent, qt_tree_item_t child);
int         qt_tree_item_child_count(qt_tree_item_t item);
qt_tree_item_t qt_tree_item_child(qt_tree_item_t item, int index);
qt_tree_item_t qt_tree_item_parent(qt_tree_item_t item);
void        qt_tree_item_set_expanded(qt_tree_item_t item, int expanded);
int         qt_tree_item_is_expanded(qt_tree_item_t item);

/* ========== Phase 6: Style Sheets, Window State, ScrollArea, Splitter, Keys ========== */

typedef void* qt_scroll_area_t;
typedef void* qt_splitter_t;

/* --- App-wide Style Sheet --- */
void qt_application_set_style_sheet(qt_application_t app, const char* css);

/* --- Window State Management --- */
void qt_widget_show_minimized(qt_widget_t w);
void qt_widget_show_maximized(qt_widget_t w);
void qt_widget_show_fullscreen(qt_widget_t w);
void qt_widget_show_normal(qt_widget_t w);
int  qt_widget_window_state(qt_widget_t w);
void qt_widget_move(qt_widget_t w, int x, int y);
int  qt_widget_x(qt_widget_t w);
int  qt_widget_y(qt_widget_t w);
int  qt_widget_width(qt_widget_t w);
int  qt_widget_height(qt_widget_t w);
void qt_widget_set_focus(qt_widget_t w);

/* --- Scroll Area --- */
qt_scroll_area_t qt_scroll_area_create(qt_widget_t parent);
void qt_scroll_area_set_widget(qt_scroll_area_t s, qt_widget_t w);
void qt_scroll_area_set_widget_resizable(qt_scroll_area_t s, int resizable);
void qt_scroll_area_set_horizontal_scrollbar_policy(qt_scroll_area_t s, int policy);
void qt_scroll_area_set_vertical_scrollbar_policy(qt_scroll_area_t s, int policy);

/* --- Splitter --- */
qt_splitter_t qt_splitter_create(int orientation, qt_widget_t parent);
void qt_splitter_add_widget(qt_splitter_t s, qt_widget_t w);
void qt_splitter_insert_widget(qt_splitter_t s, int index, qt_widget_t w);
int  qt_splitter_index_of(qt_splitter_t s, qt_widget_t w);
qt_widget_t qt_splitter_widget(qt_splitter_t s, int index);
int  qt_splitter_count(qt_splitter_t s);
void qt_splitter_set_sizes_2(qt_splitter_t s, int a, int b);
void qt_splitter_set_sizes_3(qt_splitter_t s, int a, int b, int c);
int  qt_splitter_size_at(qt_splitter_t s, int index);
void qt_splitter_set_stretch_factor(qt_splitter_t s, int index, int stretch);
void qt_splitter_set_handle_width(qt_splitter_t s, int width);
void qt_splitter_set_collapsible(qt_splitter_t s, int index, int collapsible);
int  qt_splitter_is_collapsible(qt_splitter_t s, int index);
void qt_splitter_set_orientation(qt_splitter_t s, int orientation);

/* --- Keyboard Events --- */
void qt_widget_install_key_handler(qt_widget_t w,
                                   qt_callback_void callback,
                                   long callback_id);
void qt_widget_install_key_handler_consuming(qt_widget_t w,
                                              qt_callback_void callback,
                                              long callback_id);
int         qt_last_key_code(void);
int         qt_last_key_modifiers(void);
const char* qt_last_key_text(void);

/* ========== Phase 7: Images, Icons, Radio Buttons, GroupBox ========== */

typedef void* qt_pixmap_t;
typedef void* qt_icon_t;
typedef void* qt_radio_button_t;
typedef void* qt_button_group_t;
typedef void* qt_group_box_t;

/* --- Pixmap --- */
qt_pixmap_t qt_pixmap_load(const char* path);
int         qt_pixmap_width(qt_pixmap_t p);
int         qt_pixmap_height(qt_pixmap_t p);
int         qt_pixmap_is_null(qt_pixmap_t p);
qt_pixmap_t qt_pixmap_scaled(qt_pixmap_t p, int w, int h);
void        qt_pixmap_destroy(qt_pixmap_t p);
void        qt_label_set_pixmap(qt_label_t label, qt_pixmap_t pixmap);

/* --- Icon --- */
qt_icon_t   qt_icon_create(const char* path);
qt_icon_t   qt_icon_create_from_pixmap(qt_pixmap_t pixmap);
int         qt_icon_is_null(qt_icon_t icon);
void        qt_icon_destroy(qt_icon_t icon);
void        qt_push_button_set_icon(qt_push_button_t button, qt_icon_t icon);
void        qt_action_set_icon(qt_action_t action, qt_icon_t icon);
void        qt_widget_set_window_icon(qt_widget_t widget, qt_icon_t icon);

/* --- Radio Button --- */
qt_radio_button_t qt_radio_button_create(const char* text, qt_widget_t parent);
void        qt_radio_button_set_text(qt_radio_button_t r, const char* text);
const char* qt_radio_button_text(qt_radio_button_t r);
void        qt_radio_button_set_checked(qt_radio_button_t r, int checked);
int         qt_radio_button_is_checked(qt_radio_button_t r);
void        qt_radio_button_on_toggled(qt_radio_button_t r,
                                        qt_callback_bool callback,
                                        long callback_id);

/* --- Button Group --- */
qt_button_group_t qt_button_group_create(void);
void        qt_button_group_add_button(qt_button_group_t bg,
                                        qt_widget_t button, int id);
void        qt_button_group_remove_button(qt_button_group_t bg,
                                           qt_widget_t button);
int         qt_button_group_checked_id(qt_button_group_t bg);
void        qt_button_group_set_exclusive(qt_button_group_t bg, int exclusive);
int         qt_button_group_is_exclusive(qt_button_group_t bg);
void        qt_button_group_on_id_clicked(qt_button_group_t bg,
                                           qt_callback_int callback,
                                           long callback_id);
void        qt_button_group_destroy(qt_button_group_t bg);

/* --- Group Box --- */
qt_group_box_t qt_group_box_create(const char* title, qt_widget_t parent);
void        qt_group_box_set_title(qt_group_box_t gb, const char* title);
const char* qt_group_box_title(qt_group_box_t gb);
void        qt_group_box_set_checkable(qt_group_box_t gb, int checkable);
int         qt_group_box_is_checkable(qt_group_box_t gb);
void        qt_group_box_set_checked(qt_group_box_t gb, int checked);
int         qt_group_box_is_checked(qt_group_box_t gb);
void        qt_group_box_on_toggled(qt_group_box_t gb,
                                     qt_callback_bool callback,
                                     long callback_id);

/* ========== Phase 8: Fonts, Colors, Dialogs, Dock, Tray, Painter, DnD ========== */

typedef void* qt_font_t;
typedef void* qt_color_t;
typedef void* qt_stacked_widget_t;
typedef void* qt_dock_widget_t;
typedef void* qt_tray_icon_t;
typedef void* qt_painter_t;
typedef void* qt_drop_filter_t;

/* --- Font --- */
qt_font_t   qt_font_create(const char* family, int point_size);
const char* qt_font_family(qt_font_t f);
int         qt_font_point_size(qt_font_t f);
void        qt_font_set_bold(qt_font_t f, int bold);
int         qt_font_is_bold(qt_font_t f);
void        qt_font_set_italic(qt_font_t f, int italic);
int         qt_font_is_italic(qt_font_t f);
void        qt_font_destroy(qt_font_t f);
void        qt_widget_set_font(qt_widget_t w, qt_font_t f);
qt_font_t   qt_widget_font(qt_widget_t w);

/* --- Color --- */
qt_color_t  qt_color_create_rgb(int r, int g, int b, int a);
qt_color_t  qt_color_create_name(const char* name);
int         qt_color_red(qt_color_t c);
int         qt_color_green(qt_color_t c);
int         qt_color_blue(qt_color_t c);
int         qt_color_alpha(qt_color_t c);
const char* qt_color_name(qt_color_t c);
int         qt_color_is_valid(qt_color_t c);
void        qt_color_destroy(qt_color_t c);

/* --- Font Dialog --- */
qt_font_t   qt_font_dialog_get_font(qt_widget_t parent);

/* --- Color Dialog --- */
qt_color_t  qt_color_dialog_get_color(const char* initial, qt_widget_t parent);

/* --- Stacked Widget --- */
qt_stacked_widget_t qt_stacked_widget_create(qt_widget_t parent);
int         qt_stacked_widget_add_widget(qt_stacked_widget_t sw, qt_widget_t w);
void        qt_stacked_widget_set_current_index(qt_stacked_widget_t sw, int idx);
int         qt_stacked_widget_current_index(qt_stacked_widget_t sw);
int         qt_stacked_widget_count(qt_stacked_widget_t sw);
void        qt_stacked_widget_on_current_changed(qt_stacked_widget_t sw,
                                                  qt_callback_int callback,
                                                  long callback_id);

/* --- Dock Widget --- */
qt_dock_widget_t qt_dock_widget_create(const char* title, qt_widget_t parent);
void        qt_dock_widget_set_widget(qt_dock_widget_t dw, qt_widget_t w);
qt_widget_t qt_dock_widget_widget(qt_dock_widget_t dw);
void        qt_dock_widget_set_title(qt_dock_widget_t dw, const char* title);
const char* qt_dock_widget_title(qt_dock_widget_t dw);
void        qt_dock_widget_set_floating(qt_dock_widget_t dw, int floating);
int         qt_dock_widget_is_floating(qt_dock_widget_t dw);
void        qt_main_window_add_dock_widget(qt_main_window_t mw, int area,
                                            qt_dock_widget_t dw);

/* --- System Tray Icon --- */
qt_tray_icon_t qt_system_tray_icon_create(qt_icon_t icon, qt_widget_t parent);
void        qt_system_tray_icon_set_tooltip(qt_tray_icon_t ti, const char* text);
void        qt_system_tray_icon_set_icon(qt_tray_icon_t ti, qt_icon_t icon);
void        qt_system_tray_icon_show(qt_tray_icon_t ti);
void        qt_system_tray_icon_hide(qt_tray_icon_t ti);
void        qt_system_tray_icon_show_message(qt_tray_icon_t ti,
                                              const char* title, const char* msg,
                                              int icon_type, int msecs);
void        qt_system_tray_icon_set_context_menu(qt_tray_icon_t ti,
                                                  qt_menu_t menu);
void        qt_system_tray_icon_on_activated(qt_tray_icon_t ti,
                                              qt_callback_int callback,
                                              long callback_id);
int         qt_system_tray_icon_is_available(void);
void        qt_system_tray_icon_destroy(qt_tray_icon_t ti);

/* --- QPainter (paint onto QPixmap) --- */
qt_pixmap_t qt_pixmap_create_blank(int w, int h);
void        qt_pixmap_fill(qt_pixmap_t pm, int r, int g, int b, int a);
qt_painter_t qt_painter_create(qt_pixmap_t pixmap);
void        qt_painter_end(qt_painter_t p);
void        qt_painter_destroy(qt_painter_t p);
void        qt_painter_set_pen_color(qt_painter_t p, int r, int g, int b, int a);
void        qt_painter_set_pen_width(qt_painter_t p, int width);
void        qt_painter_set_brush_color(qt_painter_t p, int r, int g, int b, int a);
void        qt_painter_set_font(qt_painter_t p, qt_font_t font);
void        qt_painter_set_antialiasing(qt_painter_t p, int enabled);
void        qt_painter_draw_line(qt_painter_t p, int x1, int y1, int x2, int y2);
void        qt_painter_draw_rect(qt_painter_t p, int x, int y, int w, int h);
void        qt_painter_fill_rect(qt_painter_t p, int x, int y, int w, int h,
                                  int r, int g, int b, int a);
void        qt_painter_draw_ellipse(qt_painter_t p, int x, int y, int w, int h);
void        qt_painter_draw_text(qt_painter_t p, int x, int y, const char* text);
void        qt_painter_draw_text_rect(qt_painter_t p, int x, int y, int w, int h,
                                       int flags, const char* text);
void        qt_painter_draw_pixmap(qt_painter_t p, int x, int y,
                                    qt_pixmap_t pixmap);
void        qt_painter_draw_point(qt_painter_t p, int x, int y);
void        qt_painter_draw_arc(qt_painter_t p, int x, int y, int w, int h,
                                 int start_angle, int span_angle);
void        qt_painter_save(qt_painter_t p);
void        qt_painter_restore(qt_painter_t p);
void        qt_painter_translate(qt_painter_t p, int dx, int dy);
void        qt_painter_rotate(qt_painter_t p, double angle);
void        qt_painter_scale(qt_painter_t p, double sx, double sy);

/* --- Drag and Drop --- */
void        qt_widget_set_accept_drops(qt_widget_t w, int accept);
qt_drop_filter_t qt_drop_filter_install(qt_widget_t widget,
                                         qt_callback_string callback,
                                         long callback_id);
const char* qt_drop_filter_last_text(qt_drop_filter_t df);
void        qt_drop_filter_destroy(qt_drop_filter_t df);
void        qt_drag_text(qt_widget_t source, const char* text);

/* ========== Phase 9: Practical Widgets & Dialog Enhancements ========== */

typedef void* qt_double_spin_box_t;
typedef void* qt_date_edit_t;
typedef void* qt_time_edit_t;
typedef void* qt_frame_t;
typedef void* qt_progress_dialog_t;

/* Frame shape constants (QFrame::Shape) */
#define QT_FRAME_NO_FRAME     0
#define QT_FRAME_BOX          1
#define QT_FRAME_PANEL        2
#define QT_FRAME_WIN_PANEL    3
#define QT_FRAME_HLINE        4
#define QT_FRAME_VLINE        5
#define QT_FRAME_STYLED_PANEL 6

/* Frame shadow constants (QFrame::Shadow) */
#define QT_FRAME_PLAIN        0x0010
#define QT_FRAME_RAISED       0x0020
#define QT_FRAME_SUNKEN       0x0030

/* --- Double Spin Box --- */
qt_double_spin_box_t qt_double_spin_box_create(qt_widget_t parent);
void        qt_double_spin_box_set_value(qt_double_spin_box_t s, double value);
double      qt_double_spin_box_value(qt_double_spin_box_t s);
void        qt_double_spin_box_set_range(qt_double_spin_box_t s,
                                          double minimum, double maximum);
void        qt_double_spin_box_set_single_step(qt_double_spin_box_t s, double step);
void        qt_double_spin_box_set_decimals(qt_double_spin_box_t s, int decimals);
int         qt_double_spin_box_decimals(qt_double_spin_box_t s);
void        qt_double_spin_box_set_prefix(qt_double_spin_box_t s, const char* prefix);
void        qt_double_spin_box_set_suffix(qt_double_spin_box_t s, const char* suffix);
void        qt_double_spin_box_on_value_changed(qt_double_spin_box_t s,
                                                 qt_callback_string callback,
                                                 long callback_id);

/* --- Date Edit --- */
qt_date_edit_t qt_date_edit_create(qt_widget_t parent);
void        qt_date_edit_set_date(qt_date_edit_t d, int year, int month, int day);
int         qt_date_edit_year(qt_date_edit_t d);
int         qt_date_edit_month(qt_date_edit_t d);
int         qt_date_edit_day(qt_date_edit_t d);
const char* qt_date_edit_date_string(qt_date_edit_t d);
void        qt_date_edit_set_minimum_date(qt_date_edit_t d,
                                           int year, int month, int day);
void        qt_date_edit_set_maximum_date(qt_date_edit_t d,
                                           int year, int month, int day);
void        qt_date_edit_set_calendar_popup(qt_date_edit_t d, int enabled);
void        qt_date_edit_set_display_format(qt_date_edit_t d, const char* format);
void        qt_date_edit_on_date_changed(qt_date_edit_t d,
                                          qt_callback_string callback,
                                          long callback_id);

/* --- Time Edit --- */
qt_time_edit_t qt_time_edit_create(qt_widget_t parent);
void        qt_time_edit_set_time(qt_time_edit_t t, int hour, int minute, int second);
int         qt_time_edit_hour(qt_time_edit_t t);
int         qt_time_edit_minute(qt_time_edit_t t);
int         qt_time_edit_second(qt_time_edit_t t);
const char* qt_time_edit_time_string(qt_time_edit_t t);
void        qt_time_edit_set_display_format(qt_time_edit_t t, const char* format);
void        qt_time_edit_on_time_changed(qt_time_edit_t t,
                                          qt_callback_string callback,
                                          long callback_id);

/* --- Frame --- */
qt_frame_t  qt_frame_create(qt_widget_t parent);
void        qt_frame_set_frame_shape(qt_frame_t f, int shape);
int         qt_frame_frame_shape(qt_frame_t f);
void        qt_frame_set_frame_shadow(qt_frame_t f, int shadow);
int         qt_frame_frame_shadow(qt_frame_t f);
void        qt_frame_set_line_width(qt_frame_t f, int width);
int         qt_frame_line_width(qt_frame_t f);
void        qt_frame_set_mid_line_width(qt_frame_t f, int width);

/* --- Progress Dialog --- */
qt_progress_dialog_t qt_progress_dialog_create(const char* label,
                                                const char* cancel_text,
                                                int minimum, int maximum,
                                                qt_widget_t parent);
void        qt_progress_dialog_set_value(qt_progress_dialog_t pd, int value);
int         qt_progress_dialog_value(qt_progress_dialog_t pd);
void        qt_progress_dialog_set_range(qt_progress_dialog_t pd,
                                          int minimum, int maximum);
void        qt_progress_dialog_set_label_text(qt_progress_dialog_t pd,
                                               const char* text);
int         qt_progress_dialog_was_canceled(qt_progress_dialog_t pd);
void        qt_progress_dialog_set_minimum_duration(qt_progress_dialog_t pd,
                                                     int msecs);
void        qt_progress_dialog_set_auto_close(qt_progress_dialog_t pd, int enabled);
void        qt_progress_dialog_set_auto_reset(qt_progress_dialog_t pd, int enabled);
void        qt_progress_dialog_reset(qt_progress_dialog_t pd);
void        qt_progress_dialog_on_canceled(qt_progress_dialog_t pd,
                                            qt_callback_void callback,
                                            long callback_id);

/* --- Input Dialog (static convenience) --- */
const char* qt_input_dialog_get_text(qt_widget_t parent, const char* title,
                                      const char* label, const char* default_text);
int         qt_input_dialog_get_int(qt_widget_t parent, const char* title,
                                     const char* label, int value,
                                     int min_val, int max_val, int step);
double      qt_input_dialog_get_double(qt_widget_t parent, const char* title,
                                        const char* label, double value,
                                        double min_val, double max_val,
                                        int decimals);
const char* qt_input_dialog_get_item(qt_widget_t parent, const char* title,
                                      const char* label, const char* items_newline,
                                      int current, int editable);
int         qt_input_dialog_was_accepted(void);

/* ========== Phase 4: Advanced Widgets ========== */

typedef void* qt_list_widget_t;
typedef void* qt_table_widget_t;
typedef void* qt_tab_widget_t;
typedef void* qt_progress_bar_t;
typedef void* qt_slider_t;

/* --- List Widget --- */
qt_list_widget_t qt_list_widget_create(qt_widget_t parent);
void        qt_list_widget_add_item(qt_list_widget_t l, const char* text);
void        qt_list_widget_insert_item(qt_list_widget_t l, int row, const char* text);
void        qt_list_widget_remove_item(qt_list_widget_t l, int row);
int         qt_list_widget_current_row(qt_list_widget_t l);
void        qt_list_widget_set_current_row(qt_list_widget_t l, int row);
const char* qt_list_widget_item_text(qt_list_widget_t l, int row);
int         qt_list_widget_count(qt_list_widget_t l);
void        qt_list_widget_clear(qt_list_widget_t l);
void        qt_list_widget_set_item_data(qt_list_widget_t l, int row,
                                          const char* data);
const char* qt_list_widget_item_data(qt_list_widget_t l, int row);
void        qt_list_widget_on_current_row_changed(qt_list_widget_t l,
                                                   qt_callback_int callback,
                                                   long callback_id);
void        qt_list_widget_on_item_double_clicked(qt_list_widget_t l,
                                                   qt_callback_int callback,
                                                   long callback_id);

/* --- Table Widget --- */
qt_table_widget_t qt_table_widget_create(int rows, int cols, qt_widget_t parent);
void        qt_table_widget_set_item(qt_table_widget_t t, int row, int col,
                                      const char* text);
const char* qt_table_widget_item_text(qt_table_widget_t t, int row, int col);
void        qt_table_widget_set_horizontal_header_item(qt_table_widget_t t,
                                                        int col, const char* text);
void        qt_table_widget_set_vertical_header_item(qt_table_widget_t t,
                                                      int row, const char* text);
void        qt_table_widget_set_row_count(qt_table_widget_t t, int count);
void        qt_table_widget_set_column_count(qt_table_widget_t t, int count);
int         qt_table_widget_row_count(qt_table_widget_t t);
int         qt_table_widget_column_count(qt_table_widget_t t);
int         qt_table_widget_current_row(qt_table_widget_t t);
int         qt_table_widget_current_column(qt_table_widget_t t);
void        qt_table_widget_clear(qt_table_widget_t t);
void        qt_table_widget_on_cell_clicked(qt_table_widget_t t,
                                             qt_callback_void callback,
                                             long callback_id);

/* --- Tab Widget --- */
qt_tab_widget_t qt_tab_widget_create(qt_widget_t parent);
int         qt_tab_widget_add_tab(qt_tab_widget_t t, qt_widget_t page,
                                   const char* label);
void        qt_tab_widget_set_current_index(qt_tab_widget_t t, int index);
int         qt_tab_widget_current_index(qt_tab_widget_t t);
int         qt_tab_widget_count(qt_tab_widget_t t);
void        qt_tab_widget_set_tab_text(qt_tab_widget_t t, int index,
                                        const char* text);
void        qt_tab_widget_on_current_changed(qt_tab_widget_t t,
                                              qt_callback_int callback,
                                              long callback_id);

/* --- Progress Bar --- */
qt_progress_bar_t qt_progress_bar_create(qt_widget_t parent);
void        qt_progress_bar_set_value(qt_progress_bar_t p, int value);
int         qt_progress_bar_value(qt_progress_bar_t p);
void        qt_progress_bar_set_range(qt_progress_bar_t p, int minimum, int maximum);
void        qt_progress_bar_set_format(qt_progress_bar_t p, const char* format);

/* --- Slider --- */
qt_slider_t qt_slider_create(int orientation, qt_widget_t parent);
void        qt_slider_set_value(qt_slider_t s, int value);
int         qt_slider_value(qt_slider_t s);
void        qt_slider_set_range(qt_slider_t s, int minimum, int maximum);
void        qt_slider_set_single_step(qt_slider_t s, int step);
void        qt_slider_set_tick_interval(qt_slider_t s, int interval);
void        qt_slider_set_tick_position(qt_slider_t s, int position);
void        qt_slider_on_value_changed(qt_slider_t s,
                                        qt_callback_int callback,
                                        long callback_id);

/* ========== Phase 10: Forms, Dialogs, Shortcuts, Calendar, Rich Text ========== */

typedef void* qt_button_box_t;
typedef void* qt_shortcut_t;
typedef void* qt_calendar_t;
typedef void* qt_text_browser_t;

/* QDialogButtonBox standard button flags */
#define QT_BUTTON_OK        0x00000400
#define QT_BUTTON_CANCEL    0x00400000
#define QT_BUTTON_APPLY     0x02000000
#define QT_BUTTON_CLOSE     0x00200000
#define QT_BUTTON_YES       0x00004000
#define QT_BUTTON_NO        0x00010000
#define QT_BUTTON_RESET     0x04000000
#define QT_BUTTON_HELP      0x01000000
#define QT_BUTTON_SAVE      0x00000800
#define QT_BUTTON_DISCARD   0x00800000

/* QDialogButtonBox button roles */
#define QT_BUTTON_ROLE_INVALID       -1
#define QT_BUTTON_ROLE_ACCEPT         0
#define QT_BUTTON_ROLE_REJECT         1
#define QT_BUTTON_ROLE_DESTRUCTIVE    2
#define QT_BUTTON_ROLE_ACTION         3
#define QT_BUTTON_ROLE_HELP           4
#define QT_BUTTON_ROLE_YES            5
#define QT_BUTTON_ROLE_NO             6
#define QT_BUTTON_ROLE_APPLY          8
#define QT_BUTTON_ROLE_RESET          7

/* Day-of-week constants (Qt::DayOfWeek) */
#define QT_MONDAY     1
#define QT_TUESDAY    2
#define QT_WEDNESDAY  3
#define QT_THURSDAY   4
#define QT_FRIDAY     5
#define QT_SATURDAY   6
#define QT_SUNDAY     7

/* --- Form Layout --- */
qt_layout_t qt_form_layout_create(qt_widget_t parent);
void        qt_form_layout_add_row(qt_layout_t layout, const char* label,
                                   qt_widget_t field);
void        qt_form_layout_add_row_widget(qt_layout_t layout,
                                          qt_widget_t label_widget,
                                          qt_widget_t field);
void        qt_form_layout_add_spanning_widget(qt_layout_t layout,
                                                qt_widget_t widget);
int         qt_form_layout_row_count(qt_layout_t layout);

/* --- Shortcut --- */
qt_shortcut_t qt_shortcut_create(const char* key_sequence, qt_widget_t parent);
void        qt_shortcut_set_key(qt_shortcut_t s, const char* key_sequence);
void        qt_shortcut_set_enabled(qt_shortcut_t s, int enabled);
int         qt_shortcut_is_enabled(qt_shortcut_t s);
void        qt_shortcut_on_activated(qt_shortcut_t s,
                                     qt_callback_void callback,
                                     long callback_id);
void        qt_shortcut_destroy(qt_shortcut_t s);

/* --- Text Browser --- */
qt_text_browser_t qt_text_browser_create(qt_widget_t parent);
void        qt_text_browser_set_html(qt_text_browser_t tb, const char* html);
void        qt_text_browser_set_plain_text(qt_text_browser_t tb,
                                            const char* text);
const char* qt_text_browser_plain_text(qt_text_browser_t tb);
void        qt_text_browser_set_open_external_links(qt_text_browser_t tb,
                                                     int enabled);
void        qt_text_browser_set_source(qt_text_browser_t tb, const char* url);
const char* qt_text_browser_source(qt_text_browser_t tb);
void        qt_text_browser_on_anchor_clicked(qt_text_browser_t tb,
                                               qt_callback_string callback,
                                               long callback_id);
void        qt_text_browser_scroll_to_bottom(qt_text_browser_t tb);
void        qt_text_browser_append(qt_text_browser_t tb, const char* text);
const char* qt_text_browser_html(qt_text_browser_t tb);

/* --- Dialog Button Box --- */
qt_button_box_t qt_button_box_create(int standard_buttons, qt_widget_t parent);
qt_push_button_t qt_button_box_button(qt_button_box_t bb, int standard_button);
void        qt_button_box_add_button(qt_button_box_t bb,
                                      qt_push_button_t button, int role);
void        qt_button_box_on_accepted(qt_button_box_t bb,
                                       qt_callback_void callback,
                                       long callback_id);
void        qt_button_box_on_rejected(qt_button_box_t bb,
                                       qt_callback_void callback,
                                       long callback_id);
void        qt_button_box_on_clicked(qt_button_box_t bb,
                                      qt_callback_void callback,
                                      long callback_id);

/* --- Calendar Widget --- */
qt_calendar_t qt_calendar_create(qt_widget_t parent);
void        qt_calendar_set_selected_date(qt_calendar_t c,
                                           int year, int month, int day);
int         qt_calendar_selected_year(qt_calendar_t c);
int         qt_calendar_selected_month(qt_calendar_t c);
int         qt_calendar_selected_day(qt_calendar_t c);
const char* qt_calendar_selected_date_string(qt_calendar_t c);
void        qt_calendar_set_minimum_date(qt_calendar_t c,
                                          int year, int month, int day);
void        qt_calendar_set_maximum_date(qt_calendar_t c,
                                          int year, int month, int day);
void        qt_calendar_set_first_day_of_week(qt_calendar_t c, int day);
void        qt_calendar_set_grid_visible(qt_calendar_t c, int visible);
int         qt_calendar_is_grid_visible(qt_calendar_t c);
void        qt_calendar_set_navigation_bar_visible(qt_calendar_t c, int visible);
void        qt_calendar_on_selection_changed(qt_calendar_t c,
                                              qt_callback_void callback,
                                              long callback_id);
void        qt_calendar_on_clicked(qt_calendar_t c,
                                    qt_callback_string callback,
                                    long callback_id);

/* ========== Phase 11: QSettings, QCompleter, QToolTip ========== */

typedef void* qt_settings_t;
typedef void* qt_completer_t;

/* QSettings format constants */
#define QT_SETTINGS_NATIVE  0
#define QT_SETTINGS_INI     1

/* QCompleter completion mode constants */
#define QT_COMPLETER_POPUP              0
#define QT_COMPLETER_INLINE             1
#define QT_COMPLETER_UNFILTERED_POPUP   2

/* Case sensitivity constants */
#define QT_CASE_INSENSITIVE  0
#define QT_CASE_SENSITIVE    1

/* Filter mode constants (simplified mapping to Qt::MatchFlags) */
#define QT_MATCH_STARTS_WITH  0
#define QT_MATCH_CONTAINS     1
#define QT_MATCH_ENDS_WITH    2

/* --- QSettings --- */
qt_settings_t qt_settings_create(const char* org, const char* app);
qt_settings_t qt_settings_create_file(const char* path, int format);
void        qt_settings_set_string(qt_settings_t s, const char* key,
                                   const char* value);
const char* qt_settings_value_string(qt_settings_t s, const char* key,
                                     const char* default_value);
void        qt_settings_set_int(qt_settings_t s, const char* key, int value);
int         qt_settings_value_int(qt_settings_t s, const char* key,
                                  int default_value);
void        qt_settings_set_double(qt_settings_t s, const char* key,
                                   double value);
double      qt_settings_value_double(qt_settings_t s, const char* key,
                                     double default_value);
void        qt_settings_set_bool(qt_settings_t s, const char* key, int value);
int         qt_settings_value_bool(qt_settings_t s, const char* key,
                                   int default_value);
int         qt_settings_contains(qt_settings_t s, const char* key);
void        qt_settings_remove(qt_settings_t s, const char* key);
const char* qt_settings_all_keys(qt_settings_t s);
const char* qt_settings_child_keys(qt_settings_t s);
const char* qt_settings_child_groups(qt_settings_t s);
void        qt_settings_begin_group(qt_settings_t s, const char* prefix);
void        qt_settings_end_group(qt_settings_t s);
const char* qt_settings_group(qt_settings_t s);
void        qt_settings_sync(qt_settings_t s);
void        qt_settings_clear(qt_settings_t s);
const char* qt_settings_file_name(qt_settings_t s);
int         qt_settings_is_writable(qt_settings_t s);
void        qt_settings_destroy(qt_settings_t s);

/* --- QCompleter --- */
qt_completer_t qt_completer_create(const char* items_newline);
void        qt_completer_set_model_strings(qt_completer_t c,
                                           const char* items_newline);
void        qt_completer_set_case_sensitivity(qt_completer_t c, int cs);
void        qt_completer_set_completion_mode(qt_completer_t c, int mode);
void        qt_completer_set_filter_mode(qt_completer_t c, int mode);
void        qt_completer_set_max_visible_items(qt_completer_t c, int count);
int         qt_completer_completion_count(qt_completer_t c);
const char* qt_completer_current_completion(qt_completer_t c);
void        qt_completer_set_completion_prefix(qt_completer_t c,
                                               const char* prefix);
void        qt_completer_on_activated(qt_completer_t c,
                                      qt_callback_string callback,
                                      long callback_id);
void        qt_line_edit_set_completer(qt_line_edit_t e, qt_completer_t c);
void        qt_completer_destroy(qt_completer_t c);

/* --- QToolTip / QWhatsThis --- */
void        qt_tooltip_show_text(int x, int y, const char* text,
                                 qt_widget_t widget);
void        qt_tooltip_hide_text(void);
int         qt_tooltip_is_visible(void);
const char* qt_widget_tooltip(qt_widget_t w);
void        qt_widget_set_whats_this(qt_widget_t w, const char* text);
const char* qt_widget_whats_this(qt_widget_t w);

/* --- Phase 12: Model/View Framework --- */

/* Opaque handle types */
typedef void* qt_standard_model_t;
typedef void* qt_standard_item_t;
typedef void* qt_string_list_model_t;
typedef void* qt_sort_filter_proxy_t;
typedef void* qt_list_view_t;
typedef void* qt_table_view_t;
typedef void* qt_tree_view_t;

/* --- QStandardItemModel --- */
qt_standard_model_t qt_standard_model_create(int rows, int cols,
                                              qt_widget_t parent);
void        qt_standard_model_destroy(qt_standard_model_t m);
int         qt_standard_model_row_count(qt_standard_model_t m);
int         qt_standard_model_column_count(qt_standard_model_t m);
void        qt_standard_model_set_row_count(qt_standard_model_t m, int rows);
void        qt_standard_model_set_column_count(qt_standard_model_t m, int cols);
void        qt_standard_model_set_item(qt_standard_model_t m, int row, int col,
                                        qt_standard_item_t item);
qt_standard_item_t qt_standard_model_item(qt_standard_model_t m,
                                           int row, int col);
int         qt_standard_model_insert_row(qt_standard_model_t m, int row);
int         qt_standard_model_insert_column(qt_standard_model_t m, int col);
int         qt_standard_model_remove_row(qt_standard_model_t m, int row);
int         qt_standard_model_remove_column(qt_standard_model_t m, int col);
void        qt_standard_model_clear(qt_standard_model_t m);
void        qt_standard_model_set_horizontal_header(qt_standard_model_t m,
                                                     int col, const char* text);
void        qt_standard_model_set_vertical_header(qt_standard_model_t m,
                                                    int row, const char* text);

/* --- QStandardItem --- */
qt_standard_item_t qt_standard_item_create(const char* text);
const char* qt_standard_item_text(qt_standard_item_t item);
void        qt_standard_item_set_text(qt_standard_item_t item,
                                       const char* text);
const char* qt_standard_item_tooltip(qt_standard_item_t item);
void        qt_standard_item_set_tooltip(qt_standard_item_t item,
                                          const char* text);
void        qt_standard_item_set_editable(qt_standard_item_t item, int val);
int         qt_standard_item_is_editable(qt_standard_item_t item);
void        qt_standard_item_set_enabled(qt_standard_item_t item, int val);
int         qt_standard_item_is_enabled(qt_standard_item_t item);
void        qt_standard_item_set_selectable(qt_standard_item_t item, int val);
int         qt_standard_item_is_selectable(qt_standard_item_t item);
void        qt_standard_item_set_checkable(qt_standard_item_t item, int val);
int         qt_standard_item_is_checkable(qt_standard_item_t item);
void        qt_standard_item_set_check_state(qt_standard_item_t item, int state);
int         qt_standard_item_check_state(qt_standard_item_t item);
void        qt_standard_item_set_icon(qt_standard_item_t item, void* icon);
void        qt_standard_item_append_row(qt_standard_item_t parent,
                                         qt_standard_item_t child);
int         qt_standard_item_row_count(qt_standard_item_t item);
int         qt_standard_item_column_count(qt_standard_item_t item);
qt_standard_item_t qt_standard_item_child(qt_standard_item_t item,
                                            int row, int col);

/* --- QStringListModel --- */
qt_string_list_model_t qt_string_list_model_create(const char* items_newline);
void        qt_string_list_model_destroy(qt_string_list_model_t m);
void        qt_string_list_model_set_strings(qt_string_list_model_t m,
                                              const char* items_newline);
const char* qt_string_list_model_strings(qt_string_list_model_t m);
int         qt_string_list_model_row_count(qt_string_list_model_t m);

/* --- Common view functions (QAbstractItemView) --- */
void        qt_view_set_model(qt_widget_t view, void* model);
void        qt_view_set_selection_mode(qt_widget_t view, int mode);
void        qt_view_set_selection_behavior(qt_widget_t view, int behavior);
void        qt_view_set_alternating_row_colors(qt_widget_t view, int val);
void        qt_view_set_sorting_enabled(qt_widget_t view, int val);
void        qt_view_set_edit_triggers(qt_widget_t view, int triggers);

/* --- QListView --- */
qt_list_view_t qt_list_view_create(qt_widget_t parent);
void        qt_list_view_set_flow(qt_list_view_t v, int flow);

/* --- QTableView --- */
qt_table_view_t qt_table_view_create(qt_widget_t parent);
void        qt_table_view_set_column_width(qt_table_view_t v, int col, int w);
void        qt_table_view_set_row_height(qt_table_view_t v, int row, int h);
void        qt_table_view_hide_column(qt_table_view_t v, int col);
void        qt_table_view_show_column(qt_table_view_t v, int col);
void        qt_table_view_hide_row(qt_table_view_t v, int row);
void        qt_table_view_show_row(qt_table_view_t v, int row);
void        qt_table_view_resize_columns_to_contents(qt_table_view_t v);
void        qt_table_view_resize_rows_to_contents(qt_table_view_t v);

/* --- QTreeView --- */
qt_tree_view_t qt_tree_view_create(qt_widget_t parent);
void        qt_tree_view_expand_all(qt_tree_view_t v);
void        qt_tree_view_collapse_all(qt_tree_view_t v);
void        qt_tree_view_set_indentation(qt_tree_view_t v, int indent);
int         qt_tree_view_indentation(qt_tree_view_t v);
void        qt_tree_view_set_root_is_decorated(qt_tree_view_t v, int val);
void        qt_tree_view_set_header_hidden(qt_tree_view_t v, int val);
void        qt_tree_view_set_column_width(qt_tree_view_t v, int col, int w);

/* --- QHeaderView (via view) --- */
void        qt_view_header_set_stretch_last_section(qt_widget_t view,
                                                     int horizontal, int val);
void        qt_view_header_set_section_resize_mode(qt_widget_t view,
                                                    int horizontal, int mode);
void        qt_view_header_hide(qt_widget_t view, int horizontal);
void        qt_view_header_show(qt_widget_t view, int horizontal);
void        qt_view_header_set_default_section_size(qt_widget_t view,
                                                     int horizontal, int size);

/* --- QSortFilterProxyModel --- */
qt_sort_filter_proxy_t qt_sort_filter_proxy_create(void* parent);
void        qt_sort_filter_proxy_destroy(qt_sort_filter_proxy_t p);
void        qt_sort_filter_proxy_set_source_model(qt_sort_filter_proxy_t p,
                                                   void* model);
void        qt_sort_filter_proxy_set_filter_regex(qt_sort_filter_proxy_t p,
                                                   const char* pattern);
void        qt_sort_filter_proxy_set_filter_column(qt_sort_filter_proxy_t p,
                                                    int col);
void        qt_sort_filter_proxy_set_filter_case_sensitivity(
                qt_sort_filter_proxy_t p, int cs);
void        qt_sort_filter_proxy_set_filter_role(qt_sort_filter_proxy_t p,
                                                  int role);
void        qt_sort_filter_proxy_sort(qt_sort_filter_proxy_t p,
                                       int col, int order);
void        qt_sort_filter_proxy_set_sort_role(qt_sort_filter_proxy_t p,
                                                int role);
void        qt_sort_filter_proxy_set_dynamic_sort_filter(
                qt_sort_filter_proxy_t p, int val);
void        qt_sort_filter_proxy_invalidate_filter(qt_sort_filter_proxy_t p);
int         qt_sort_filter_proxy_row_count(qt_sort_filter_proxy_t p);

/* --- View signals + selection --- */
void        qt_view_on_clicked(qt_widget_t view, qt_callback_void callback,
                                long callback_id);
void        qt_view_on_double_clicked(qt_widget_t view,
                                       qt_callback_void callback,
                                       long callback_id);
void        qt_view_on_activated(qt_widget_t view, qt_callback_void callback,
                                  long callback_id);
void        qt_view_on_selection_changed(qt_widget_t view,
                                          qt_callback_void callback,
                                          long callback_id);
int         qt_view_last_clicked_row(void);
int         qt_view_last_clicked_col(void);
const char* qt_view_selected_rows(qt_widget_t view);
int         qt_view_current_row(qt_widget_t view);

/* ========== Phase 13: Practical Polish ========== */

typedef void* qt_validator_t;
typedef void* qt_plain_text_edit_t;
typedef void* qt_tool_button_t;

/* --- Validator state constants --- */
#define QT_VALIDATOR_INVALID       0
#define QT_VALIDATOR_INTERMEDIATE  1
#define QT_VALIDATOR_ACCEPTABLE    2

/* --- PlainTextEdit line wrap modes --- */
#define QT_PLAIN_NO_WRAP    0
#define QT_PLAIN_WIDGET_WRAP 1

/* --- ToolButton popup modes --- */
#define QT_DELAYED_POPUP     0
#define QT_MENU_BUTTON_POPUP 1
#define QT_INSTANT_POPUP     2

/* --- ToolButton arrow types --- */
#define QT_NO_ARROW    0
#define QT_UP_ARROW    1
#define QT_DOWN_ARROW  2
#define QT_LEFT_ARROW  3
#define QT_RIGHT_ARROW 4

/* --- ToolButton styles --- */
#define QT_TOOL_BUTTON_ICON_ONLY         0
#define QT_TOOL_BUTTON_TEXT_ONLY         1
#define QT_TOOL_BUTTON_TEXT_BESIDE_ICON  2
#define QT_TOOL_BUTTON_TEXT_UNDER_ICON   3

/* --- QSizePolicy constants --- */
#define QT_SIZE_FIXED              0
#define QT_SIZE_MINIMUM            1
#define QT_SIZE_MINIMUM_EXPANDING  3
#define QT_SIZE_MAXIMUM            4
#define QT_SIZE_PREFERRED          5
#define QT_SIZE_EXPANDING          7
#define QT_SIZE_IGNORED            13

/* --- QValidator --- */
qt_validator_t qt_int_validator_create(int minimum, int maximum,
                                       qt_widget_t parent);
qt_validator_t qt_double_validator_create(double bottom, double top,
                                           int decimals, qt_widget_t parent);
qt_validator_t qt_regex_validator_create(const char* pattern,
                                          qt_widget_t parent);
void           qt_validator_destroy(qt_validator_t v);
int            qt_validator_validate(qt_validator_t v, const char* input);
void           qt_line_edit_set_validator(qt_line_edit_t e, qt_validator_t v);
int            qt_line_edit_has_acceptable_input(qt_line_edit_t e);

/* --- QPlainTextEdit --- */
qt_plain_text_edit_t qt_plain_text_edit_create(qt_widget_t parent);
void        qt_plain_text_edit_set_text(qt_plain_text_edit_t e,
                                         const char* text);
const char* qt_plain_text_edit_text(qt_plain_text_edit_t e);
void        qt_plain_text_edit_append(qt_plain_text_edit_t e,
                                       const char* text);
void        qt_plain_text_edit_clear(qt_plain_text_edit_t e);
void        qt_plain_text_edit_set_read_only(qt_plain_text_edit_t e,
                                              int read_only);
int         qt_plain_text_edit_is_read_only(qt_plain_text_edit_t e);
void        qt_plain_text_edit_set_placeholder(qt_plain_text_edit_t e,
                                                const char* text);
int         qt_plain_text_edit_line_count(qt_plain_text_edit_t e);
void        qt_plain_text_edit_set_max_block_count(qt_plain_text_edit_t e,
                                                     int count);
int         qt_plain_text_edit_cursor_line(qt_plain_text_edit_t e);
int         qt_plain_text_edit_cursor_column(qt_plain_text_edit_t e);
void        qt_plain_text_edit_set_line_wrap(qt_plain_text_edit_t e,
                                              int mode);
void        qt_plain_text_edit_on_text_changed(qt_plain_text_edit_t e,
                                                qt_callback_void callback,
                                                long callback_id);

/* --- QToolButton --- */
qt_tool_button_t qt_tool_button_create(qt_widget_t parent);
void        qt_tool_button_set_text(qt_tool_button_t b, const char* text);
const char* qt_tool_button_text(qt_tool_button_t b);
void        qt_tool_button_set_icon(qt_tool_button_t b, const char* path);
void        qt_tool_button_set_menu(qt_tool_button_t b, qt_widget_t menu);
void        qt_tool_button_set_popup_mode(qt_tool_button_t b, int mode);
void        qt_tool_button_set_auto_raise(qt_tool_button_t b, int val);
void        qt_tool_button_set_arrow_type(qt_tool_button_t b, int arrow);
void        qt_tool_button_set_tool_button_style(qt_tool_button_t b,
                                                   int style);
void        qt_tool_button_on_clicked(qt_tool_button_t b,
                                       qt_callback_void callback,
                                       long callback_id);

/* --- Layout spacers --- */
void qt_layout_add_spacing(qt_layout_t layout, int size);

/* --- QSizePolicy --- */
void qt_widget_set_size_policy(qt_widget_t w, int h_policy, int v_policy);
void qt_layout_set_stretch_factor(qt_layout_t layout, qt_widget_t widget,
                                   int stretch);

/* ========== Phase 14: Graphics Scene & Custom Painting ========== */

typedef void* qt_graphics_scene_t;
typedef void* qt_graphics_view_t;
typedef void* qt_graphics_item_t;
typedef void* qt_paint_widget_t;

/* Graphics item flags */
#define QT_ITEM_MOVABLE    0x1
#define QT_ITEM_SELECTABLE 0x2
#define QT_ITEM_FOCUSABLE  0x4

/* Graphics view drag modes */
#define QT_DRAG_NONE        0
#define QT_DRAG_SCROLL      1
#define QT_DRAG_RUBBER_BAND 2

/* Render hints */
#define QT_RENDER_ANTIALIASING      0x01
#define QT_RENDER_SMOOTH_PIXMAP     0x02
#define QT_RENDER_TEXT_ANTIALIASING  0x04

/* --- QGraphicsScene --- */
qt_graphics_scene_t qt_graphics_scene_create(double x, double y,
                                              double w, double h);
qt_graphics_item_t  qt_graphics_scene_add_rect(qt_graphics_scene_t scene,
                                                double x, double y,
                                                double w, double h);
qt_graphics_item_t  qt_graphics_scene_add_ellipse(qt_graphics_scene_t scene,
                                                   double x, double y,
                                                   double w, double h);
qt_graphics_item_t  qt_graphics_scene_add_line(qt_graphics_scene_t scene,
                                                double x1, double y1,
                                                double x2, double y2);
qt_graphics_item_t  qt_graphics_scene_add_text(qt_graphics_scene_t scene,
                                                const char* text);
qt_graphics_item_t  qt_graphics_scene_add_pixmap(qt_graphics_scene_t scene,
                                                  qt_pixmap_t pixmap);
void                qt_graphics_scene_remove_item(qt_graphics_scene_t scene,
                                                   qt_graphics_item_t item);
void                qt_graphics_scene_clear(qt_graphics_scene_t scene);
int                 qt_graphics_scene_items_count(qt_graphics_scene_t scene);
void                qt_graphics_scene_set_background(qt_graphics_scene_t scene,
                                                      int r, int g, int b);
void                qt_graphics_scene_destroy(qt_graphics_scene_t scene);

/* --- QGraphicsView --- */
qt_graphics_view_t qt_graphics_view_create(qt_graphics_scene_t scene,
                                            qt_widget_t parent);
void               qt_graphics_view_set_render_hint(qt_graphics_view_t view,
                                                     int hint, int on);
void               qt_graphics_view_set_drag_mode(qt_graphics_view_t view,
                                                    int mode);
void               qt_graphics_view_fit_in_view(qt_graphics_view_t view);
void               qt_graphics_view_scale(qt_graphics_view_t view,
                                           double sx, double sy);
void               qt_graphics_view_center_on(qt_graphics_view_t view,
                                               double x, double y);

/* --- QGraphicsItem --- */
void qt_graphics_item_set_pos(qt_graphics_item_t item, double x, double y);
double qt_graphics_item_x(qt_graphics_item_t item);
double qt_graphics_item_y(qt_graphics_item_t item);
void qt_graphics_item_set_pen(qt_graphics_item_t item,
                               int r, int g, int b, int width);
void qt_graphics_item_set_brush(qt_graphics_item_t item, int r, int g, int b);
void qt_graphics_item_set_flags(qt_graphics_item_t item, int flags);
void qt_graphics_item_set_tooltip(qt_graphics_item_t item, const char* text);
void qt_graphics_item_set_zvalue(qt_graphics_item_t item, double z);
double qt_graphics_item_zvalue(qt_graphics_item_t item);
void qt_graphics_item_set_rotation(qt_graphics_item_t item, double angle);
void qt_graphics_item_set_scale(qt_graphics_item_t item, double factor);
void qt_graphics_item_set_visible(qt_graphics_item_t item, int visible);

/* --- PaintWidget (custom paintEvent) --- */
qt_paint_widget_t qt_paint_widget_create(qt_widget_t parent);
void              qt_paint_widget_on_paint(qt_paint_widget_t w,
                                            qt_callback_void callback,
                                            long callback_id);
qt_painter_t      qt_paint_widget_painter(qt_paint_widget_t w);
void              qt_paint_widget_update(qt_paint_widget_t w);
int               qt_paint_widget_width(qt_paint_widget_t w);
int               qt_paint_widget_height(qt_paint_widget_t w);

/* Phase 15: QProcess state */
#define QT_PROCESS_NOT_RUNNING 0
#define QT_PROCESS_STARTING    1
#define QT_PROCESS_RUNNING     2

/* Phase 15: QMdiArea view mode */
#define QT_MDI_SUBWINDOW 0
#define QT_MDI_TABBED    1

/* Phase 16: QLCDNumber mode */
#define QT_LCD_DEC     0
#define QT_LCD_HEX     1
#define QT_LCD_OCT     2
#define QT_LCD_BIN     3

/* Phase 16: QLCDNumber segment style */
#define QT_LCD_OUTLINE 0
#define QT_LCD_FILLED  1
#define QT_LCD_FLAT    2

/* Phase 16: QDir filter flags (for QFileSystemModel) */
#define QT_DIR_DIRS              0x001
#define QT_DIR_FILES             0x002
#define QT_DIR_HIDDEN            0x100
#define QT_DIR_NO_DOT_AND_DOT_DOT 0x1000

/* ========== Phase 15: Process, Wizard, MDI ========== */

typedef void* qt_process_t;
typedef void* qt_wizard_t;
typedef void* qt_wizard_page_t;
typedef void* qt_mdi_area_t;
typedef void* qt_mdi_sub_window_t;

/* --- QProcess --- */
qt_process_t qt_process_create(qt_widget_t parent);
int          qt_process_start(qt_process_t proc, const char* program,
                               const char* args_str);
void         qt_process_write(qt_process_t proc, const char* data);
void         qt_process_close_write(qt_process_t proc);
const char*  qt_process_read_stdout(qt_process_t proc);
const char*  qt_process_read_stderr(qt_process_t proc);
int          qt_process_wait_for_finished(qt_process_t proc, int msecs);
int          qt_process_exit_code(qt_process_t proc);
int          qt_process_state(qt_process_t proc);
void         qt_process_kill(qt_process_t proc);
void         qt_process_terminate(qt_process_t proc);
void         qt_process_on_finished(qt_process_t proc,
                                     qt_callback_int callback,
                                     long callback_id);
void         qt_process_on_ready_read(qt_process_t proc,
                                       qt_callback_void callback,
                                       long callback_id);
void         qt_process_destroy(qt_process_t proc);

/* --- QWizard / QWizardPage --- */
qt_wizard_t      qt_wizard_create(qt_widget_t parent);
int              qt_wizard_add_page(qt_wizard_t wiz, qt_wizard_page_t page);
void             qt_wizard_set_start_id(qt_wizard_t wiz, int id);
int              qt_wizard_current_id(qt_wizard_t wiz);
void             qt_wizard_set_title(qt_wizard_t wiz, const char* title);
int              qt_wizard_exec(qt_wizard_t wiz);
qt_wizard_page_t qt_wizard_page_create(qt_widget_t parent);
void             qt_wizard_page_set_title(qt_wizard_page_t page,
                                           const char* title);
void             qt_wizard_page_set_subtitle(qt_wizard_page_t page,
                                              const char* subtitle);
void             qt_wizard_page_set_layout(qt_wizard_page_t page,
                                            qt_layout_t layout);
void             qt_wizard_on_current_changed(qt_wizard_t wiz,
                                               qt_callback_int callback,
                                               long callback_id);

/* --- QMdiArea / QMdiSubWindow --- */
qt_mdi_area_t       qt_mdi_area_create(qt_widget_t parent);
qt_mdi_sub_window_t qt_mdi_area_add_sub_window(qt_mdi_area_t area,
                                                 qt_widget_t widget);
void                qt_mdi_area_remove_sub_window(qt_mdi_area_t area,
                                                   qt_mdi_sub_window_t sub);
qt_mdi_sub_window_t qt_mdi_area_active_sub_window(qt_mdi_area_t area);
int                 qt_mdi_area_sub_window_count(qt_mdi_area_t area);
void                qt_mdi_area_cascade(qt_mdi_area_t area);
void                qt_mdi_area_tile(qt_mdi_area_t area);
void                qt_mdi_area_set_view_mode(qt_mdi_area_t area, int mode);
void                qt_mdi_sub_window_set_title(qt_mdi_sub_window_t sub,
                                                 const char* title);
void                qt_mdi_area_on_sub_window_activated(qt_mdi_area_t area,
                                                         qt_callback_void callback,
                                                         long callback_id);

// ============================================================
// Phase 16: QDial, QLCDNumber, QToolBox, QUndoStack, QFileSystemModel
// ============================================================

// -- QDial --
typedef void* qt_dial_t;
qt_dial_t           qt_dial_create(qt_widget_t parent);
void                qt_dial_set_value(qt_dial_t d, int val);
int                 qt_dial_value(qt_dial_t d);
void                qt_dial_set_range(qt_dial_t d, int min, int max);
void                qt_dial_set_notches_visible(qt_dial_t d, int visible);
void                qt_dial_set_wrapping(qt_dial_t d, int wrap);
void                qt_dial_on_value_changed(qt_dial_t d,
                                              qt_callback_int callback,
                                              long callback_id);

// -- QLCDNumber --
typedef void* qt_lcd_t;
qt_lcd_t            qt_lcd_create(int digits, qt_widget_t parent);
void                qt_lcd_display_int(qt_lcd_t lcd, int value);
void                qt_lcd_display_double(qt_lcd_t lcd, double value);
void                qt_lcd_display_string(qt_lcd_t lcd, const char* text);
void                qt_lcd_set_mode(qt_lcd_t lcd, int mode);
void                qt_lcd_set_segment_style(qt_lcd_t lcd, int style);

// -- QToolBox --
typedef void* qt_tool_box_t;
qt_tool_box_t       qt_tool_box_create(qt_widget_t parent);
int                 qt_tool_box_add_item(qt_tool_box_t tb, qt_widget_t widget,
                                          const char* text);
void                qt_tool_box_set_current_index(qt_tool_box_t tb, int idx);
int                 qt_tool_box_current_index(qt_tool_box_t tb);
int                 qt_tool_box_count(qt_tool_box_t tb);
void                qt_tool_box_set_item_text(qt_tool_box_t tb, int idx,
                                               const char* text);
void                qt_tool_box_on_current_changed(qt_tool_box_t tb,
                                                    qt_callback_int callback,
                                                    long callback_id);

// -- QUndoStack --
typedef void* qt_undo_stack_t;
qt_undo_stack_t     qt_undo_stack_create(qt_widget_t parent);
void                qt_undo_stack_push(qt_undo_stack_t stack, const char* text,
                                        qt_callback_void undo_cb, long undo_id,
                                        qt_callback_void redo_cb, long redo_id,
                                        qt_callback_void cleanup_cb, long cleanup_id);
void                qt_undo_stack_undo(qt_undo_stack_t stack);
void                qt_undo_stack_redo(qt_undo_stack_t stack);
int                 qt_undo_stack_can_undo(qt_undo_stack_t stack);
int                 qt_undo_stack_can_redo(qt_undo_stack_t stack);
const char*         qt_undo_stack_undo_text(qt_undo_stack_t stack);
const char*         qt_undo_stack_redo_text(qt_undo_stack_t stack);
void                qt_undo_stack_clear(qt_undo_stack_t stack);
qt_action_t         qt_undo_stack_create_undo_action(qt_undo_stack_t stack,
                                                       qt_widget_t parent);
qt_action_t         qt_undo_stack_create_redo_action(qt_undo_stack_t stack,
                                                       qt_widget_t parent);
void                qt_undo_stack_destroy(qt_undo_stack_t stack);

// -- QFileSystemModel --
typedef void* qt_file_system_model_t;
qt_file_system_model_t qt_file_system_model_create(qt_widget_t parent);
void                qt_file_system_model_set_root_path(qt_file_system_model_t model,
                                                        const char* path);
void                qt_file_system_model_set_filter(qt_file_system_model_t model,
                                                     int filters);
void                qt_file_system_model_set_name_filters(qt_file_system_model_t model,
                                                           const char* patterns);
const char*         qt_file_system_model_file_path(qt_file_system_model_t model,
                                                    int row, int column);
void                qt_tree_view_set_file_system_root(qt_widget_t view,
                                                       qt_file_system_model_t model,
                                                       const char* path);
void                qt_file_system_model_destroy(qt_file_system_model_t model);

/* --- Signal disconnect --- */
void qt_disconnect_all(qt_widget_t obj);

/* ========== Phase 18: QSyntaxHighlighter ========== */

typedef void* qt_syntax_highlighter_t;

qt_syntax_highlighter_t qt_syntax_highlighter_create(void* document);
void qt_syntax_highlighter_destroy(qt_syntax_highlighter_t h);
void qt_syntax_highlighter_add_rule(qt_syntax_highlighter_t h,
    const char* pattern, int fg_r, int fg_g, int fg_b, int bold, int italic);
void qt_syntax_highlighter_add_keywords(qt_syntax_highlighter_t h,
    const char* keywords, int fg_r, int fg_g, int fg_b, int bold, int italic);
void qt_syntax_highlighter_add_multiline_rule(qt_syntax_highlighter_t h,
    const char* start_pattern, const char* end_pattern,
    int fg_r, int fg_g, int fg_b, int bold, int italic);
void qt_syntax_highlighter_clear_rules(qt_syntax_highlighter_t h);
void qt_syntax_highlighter_rehighlight(qt_syntax_highlighter_t h);

/* ========== Phase 17: QPlainTextEdit Editor Extensions ========== */

/* QTextCursor::MoveOperation constants */
#define QT_CURSOR_NO_MOVE           0
#define QT_CURSOR_START             1
#define QT_CURSOR_UP                2
#define QT_CURSOR_START_OF_LINE     3
#define QT_CURSOR_START_OF_BLOCK    4
#define QT_CURSOR_PREVIOUS_CHAR     5
#define QT_CURSOR_PREVIOUS_BLOCK    6
#define QT_CURSOR_END_OF_LINE       7
#define QT_CURSOR_END_OF_BLOCK      8
#define QT_CURSOR_NEXT_CHAR         9
#define QT_CURSOR_NEXT_BLOCK       10
#define QT_CURSOR_END              11
#define QT_CURSOR_DOWN             12
#define QT_CURSOR_LEFT             13
#define QT_CURSOR_WORD_LEFT        14
#define QT_CURSOR_NEXT_WORD        15
#define QT_CURSOR_RIGHT            16
#define QT_CURSOR_WORD_RIGHT       17
#define QT_CURSOR_PREVIOUS_WORD    18

/* QTextCursor::MoveMode */
#define QT_MOVE_ANCHOR  0
#define QT_KEEP_ANCHOR  1

/* QTextDocument::FindFlag */
#define QT_FIND_BACKWARD        1
#define QT_FIND_CASE_SENSITIVE  2
#define QT_FIND_WHOLE_WORDS     4

/* --- Cursor position --- */
int  qt_plain_text_edit_cursor_position(qt_plain_text_edit_t e);
void qt_plain_text_edit_set_cursor_position(qt_plain_text_edit_t e, int pos);
void qt_plain_text_edit_move_cursor(qt_plain_text_edit_t e, int operation,
                                     int mode);

/* --- Selection --- */
void        qt_plain_text_edit_select_all(qt_plain_text_edit_t e);
const char* qt_plain_text_edit_selected_text(qt_plain_text_edit_t e);
int         qt_plain_text_edit_selection_start(qt_plain_text_edit_t e);
int         qt_plain_text_edit_selection_end(qt_plain_text_edit_t e);
void        qt_plain_text_edit_set_selection(qt_plain_text_edit_t e,
                                              int start, int end);
int         qt_plain_text_edit_has_selection(qt_plain_text_edit_t e);

/* --- Editing --- */
void qt_plain_text_edit_insert_text(qt_plain_text_edit_t e, const char* text);
void qt_plain_text_edit_remove_selected_text(qt_plain_text_edit_t e);
void qt_plain_text_edit_undo(qt_plain_text_edit_t e);
void qt_plain_text_edit_redo(qt_plain_text_edit_t e);
int  qt_plain_text_edit_can_undo(qt_plain_text_edit_t e);
void qt_plain_text_edit_cut(qt_plain_text_edit_t e);
void qt_plain_text_edit_copy(qt_plain_text_edit_t e);
void qt_plain_text_edit_paste(qt_plain_text_edit_t e);

/* --- Text access --- */
int         qt_plain_text_edit_text_length(qt_plain_text_edit_t e);
const char* qt_plain_text_edit_text_range(qt_plain_text_edit_t e,
                                           int start, int end);
int         qt_plain_text_edit_line_from_position(qt_plain_text_edit_t e,
                                                   int pos);
int         qt_plain_text_edit_line_end_position(qt_plain_text_edit_t e,
                                                  int line);

/* --- Search --- */
int qt_plain_text_edit_find_text(qt_plain_text_edit_t e, const char* text,
                                  int flags);

/* --- Scroll & visibility --- */
void qt_plain_text_edit_ensure_cursor_visible(qt_plain_text_edit_t e);
void qt_plain_text_edit_center_cursor(qt_plain_text_edit_t e);

/* --- Document management (for multi-buffer) --- */
void* qt_text_document_create(void);
void* qt_plain_text_document_create(void);  /* with QPlainTextDocumentLayout */
void  qt_text_document_destroy(void* doc);
void* qt_plain_text_edit_document(qt_plain_text_edit_t e);
void  qt_plain_text_edit_set_document(qt_plain_text_edit_t e, void* doc);
int   qt_text_document_is_modified(void* doc);
void  qt_text_document_set_modified(void* doc, int val);

/* ====== Line Number Area ====== */
void* qt_line_number_area_create(qt_plain_text_edit_t editor);
void  qt_line_number_area_destroy(void* area);
void  qt_line_number_area_set_visible(void* area, int visible);
void  qt_line_number_area_set_bg_color(void* area, int r, int g, int b);
void  qt_line_number_area_set_fg_color(void* area, int r, int g, int b);

/* ====== Extra Selections (current-line highlight, brace matching, search) ====== */
void qt_plain_text_edit_clear_extra_selections(qt_plain_text_edit_t editor);
void qt_plain_text_edit_add_extra_selection_line(qt_plain_text_edit_t editor,
         int line, int bg_r, int bg_g, int bg_b);
void qt_plain_text_edit_add_extra_selection_range(qt_plain_text_edit_t editor,
         int start, int length, int fg_r, int fg_g, int fg_b,
         int bg_r, int bg_g, int bg_b, int bold);
void qt_plain_text_edit_apply_extra_selections(qt_plain_text_edit_t editor);

/* ====== Completer on QPlainTextEdit ====== */
void qt_completer_set_widget(void* completer, void* widget);
void qt_completer_complete_rect(void* completer, int x, int y, int w, int h);

/* ====== QScintilla (Scintilla-compatible editor widget) ====== */
#ifdef QT_SCINTILLA_AVAILABLE

typedef void* qt_scintilla_t;

/* Lifecycle */
qt_scintilla_t qt_scintilla_create(qt_widget_t parent);
void           qt_scintilla_destroy(qt_scintilla_t sci);

/* Core Scintilla message passing — same protocol as SCI_* messages */
long        qt_scintilla_send_message(qt_scintilla_t sci, unsigned int msg,
                                      unsigned long wparam, long lparam);
long        qt_scintilla_send_message_string(qt_scintilla_t sci, unsigned int msg,
                                             unsigned long wparam, const char* str);
const char* qt_scintilla_receive_string(qt_scintilla_t sci, unsigned int msg,
                                        unsigned long wparam);

/* Convenience: get/set full text (avoids SCI_GETTEXT buffer dance) */
void        qt_scintilla_set_text(qt_scintilla_t sci, const char* text);
const char* qt_scintilla_get_text(qt_scintilla_t sci);
int         qt_scintilla_get_text_length(qt_scintilla_t sci);

/* Lexer (uses Scintilla's built-in lexers via QScintilla) */
void        qt_scintilla_set_lexer_language(qt_scintilla_t sci, const char* language);
const char* qt_scintilla_get_lexer_language(qt_scintilla_t sci);

/* Read-only */
void qt_scintilla_set_read_only(qt_scintilla_t sci, int read_only);
int  qt_scintilla_is_read_only(qt_scintilla_t sci);

/* Margins */
void qt_scintilla_set_margin_width(qt_scintilla_t sci, int margin, int width);
void qt_scintilla_set_margin_type(qt_scintilla_t sci, int margin, int type);

/* Focus & widget ops */
void qt_scintilla_set_focus(qt_scintilla_t sci);

/* Notifications — QScintilla signals */
void qt_scintilla_on_text_changed(qt_scintilla_t sci,
                                  qt_callback_void callback,
                                  long callback_id);
void qt_scintilla_on_char_added(qt_scintilla_t sci,
                                qt_callback_int callback,
                                long callback_id);
void qt_scintilla_on_save_point_reached(qt_scintilla_t sci,
                                        qt_callback_void callback,
                                        long callback_id);
void qt_scintilla_on_save_point_left(qt_scintilla_t sci,
                                     qt_callback_void callback,
                                     long callback_id);
void qt_scintilla_on_margin_clicked(qt_scintilla_t sci,
                                    qt_callback_int callback,
                                    long callback_id);
void qt_scintilla_on_modified(qt_scintilla_t sci,
                              qt_callback_int callback,
                              long callback_id);

#endif /* QT_SCINTILLA_AVAILABLE */

#ifdef __cplusplus
}
#endif
#endif /* QT_SHIM_H */
