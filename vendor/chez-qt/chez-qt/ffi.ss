;;; ffi.ss — Low-level FFI bindings to Qt via qt_shim + qt_chez_shim
;;;
;;; Loads shared libraries and defines foreign-procedure bindings.
;;; The high-level API lives in qt.ss.

(library (chez-qt ffi)
  (export
    ;; Callback registration (called once at init)
    ffi-set-void-callback ffi-set-string-callback
    ffi-set-int-callback ffi-set-bool-callback

    ;; Application lifecycle
    ffi-qt-app-create ffi-qt-app-exec ffi-qt-app-quit
    ffi-qt-app-process-events ffi-qt-app-destroy ffi-qt-app-is-running

    ;; Widget base
    ffi-qt-widget-create ffi-qt-widget-show ffi-qt-widget-hide
    ffi-qt-widget-close ffi-qt-widget-set-enabled ffi-qt-widget-is-enabled
    ffi-qt-widget-set-visible ffi-qt-widget-is-visible
    ffi-qt-widget-set-updates-enabled
    ffi-qt-widget-set-fixed-size ffi-qt-widget-set-minimum-size
    ffi-qt-widget-set-maximum-size
    ffi-qt-widget-set-minimum-width ffi-qt-widget-set-minimum-height
    ffi-qt-widget-set-maximum-width ffi-qt-widget-set-maximum-height
    ffi-qt-widget-set-cursor ffi-qt-widget-unset-cursor
    ffi-qt-widget-resize ffi-qt-widget-set-style-sheet ffi-qt-widget-set-attribute
    ffi-qt-widget-set-tooltip ffi-qt-widget-set-font-size
    ffi-qt-widget-destroy

    ;; Main Window
    ffi-qt-main-window-create ffi-qt-main-window-set-title
    ffi-qt-main-window-set-central-widget

    ;; Layouts
    ffi-qt-vbox-layout-create ffi-qt-hbox-layout-create
    ffi-qt-layout-add-widget ffi-qt-layout-add-stretch
    ffi-qt-layout-set-spacing ffi-qt-layout-set-margins

    ;; Labels
    ffi-qt-label-create ffi-qt-label-set-text ffi-qt-label-text
    ffi-qt-label-set-alignment ffi-qt-label-set-word-wrap

    ;; Push Button
    ffi-qt-push-button-create ffi-qt-push-button-set-text
    ffi-qt-push-button-text ffi-qt-push-button-on-clicked

    ;; Line Edit
    ffi-qt-line-edit-create ffi-qt-line-edit-set-text ffi-qt-line-edit-text
    ffi-qt-line-edit-set-placeholder ffi-qt-line-edit-set-read-only
    ffi-qt-line-edit-set-echo-mode
    ffi-qt-line-edit-on-text-changed ffi-qt-line-edit-on-return-pressed

    ;; Check Box
    ffi-qt-check-box-create ffi-qt-check-box-set-text
    ffi-qt-check-box-set-checked ffi-qt-check-box-is-checked
    ffi-qt-check-box-on-toggled

    ;; Combo Box
    ffi-qt-combo-box-create ffi-qt-combo-box-add-item
    ffi-qt-combo-box-set-current-index ffi-qt-combo-box-current-index
    ffi-qt-combo-box-current-text ffi-qt-combo-box-count
    ffi-qt-combo-box-clear ffi-qt-combo-box-on-current-index-changed

    ;; Text Edit
    ffi-qt-text-edit-create ffi-qt-text-edit-set-text ffi-qt-text-edit-text
    ffi-qt-text-edit-set-placeholder ffi-qt-text-edit-set-read-only
    ffi-qt-text-edit-append ffi-qt-text-edit-clear
    ffi-qt-text-edit-scroll-to-bottom ffi-qt-text-edit-html
    ffi-qt-text-edit-on-text-changed

    ;; Spin Box
    ffi-qt-spin-box-create ffi-qt-spin-box-set-value ffi-qt-spin-box-value
    ffi-qt-spin-box-set-range ffi-qt-spin-box-set-single-step
    ffi-qt-spin-box-set-prefix ffi-qt-spin-box-set-suffix
    ffi-qt-spin-box-on-value-changed

    ;; Dialog
    ffi-qt-dialog-create ffi-qt-dialog-exec ffi-qt-dialog-accept
    ffi-qt-dialog-reject ffi-qt-dialog-set-title

    ;; Message Box
    ffi-qt-message-box-information ffi-qt-message-box-warning
    ffi-qt-message-box-question ffi-qt-message-box-critical

    ;; File Dialog
    ffi-qt-file-dialog-open-file ffi-qt-file-dialog-save-file
    ffi-qt-file-dialog-open-directory

    ;; Menu Bar
    ffi-qt-main-window-menu-bar

    ;; Menu
    ffi-qt-menu-bar-add-menu ffi-qt-menu-add-menu
    ffi-qt-menu-add-action ffi-qt-menu-add-separator

    ;; Action
    ffi-qt-action-create ffi-qt-action-set-text ffi-qt-action-text
    ffi-qt-action-set-shortcut ffi-qt-action-set-enabled ffi-qt-action-is-enabled
    ffi-qt-action-set-checkable ffi-qt-action-is-checkable
    ffi-qt-action-set-checked ffi-qt-action-is-checked
    ffi-qt-action-set-tooltip ffi-qt-action-set-status-tip
    ffi-qt-action-on-triggered ffi-qt-action-on-toggled

    ;; Toolbar
    ffi-qt-toolbar-create ffi-qt-main-window-add-toolbar
    ffi-qt-toolbar-add-action ffi-qt-toolbar-add-separator
    ffi-qt-toolbar-add-widget ffi-qt-toolbar-set-movable
    ffi-qt-toolbar-set-icon-size

    ;; Status Bar
    ffi-qt-main-window-set-status-bar-text

    ;; Grid Layout
    ffi-qt-grid-layout-create ffi-qt-grid-layout-add-widget
    ffi-qt-grid-layout-set-row-stretch ffi-qt-grid-layout-set-column-stretch
    ffi-qt-grid-layout-set-row-minimum-height
    ffi-qt-grid-layout-set-column-minimum-width

    ;; Timer
    ffi-qt-timer-create ffi-qt-timer-start ffi-qt-timer-stop
    ffi-qt-timer-set-single-shot ffi-qt-timer-is-active
    ffi-qt-timer-interval ffi-qt-timer-set-interval
    ffi-qt-timer-on-timeout ffi-qt-timer-single-shot
    ffi-qt-timer-destroy

    ;; Clipboard
    ffi-qt-clipboard-text ffi-qt-clipboard-set-text
    ffi-qt-clipboard-on-changed

    ;; Tree Widget
    ffi-qt-tree-widget-create ffi-qt-tree-widget-set-column-count
    ffi-qt-tree-widget-column-count ffi-qt-tree-widget-set-header-label
    ffi-qt-tree-widget-set-header-item-text
    ffi-qt-tree-widget-add-top-level-item ffi-qt-tree-widget-top-level-item-count
    ffi-qt-tree-widget-top-level-item ffi-qt-tree-widget-current-item
    ffi-qt-tree-widget-set-current-item
    ffi-qt-tree-widget-expand-item ffi-qt-tree-widget-collapse-item
    ffi-qt-tree-widget-expand-all ffi-qt-tree-widget-collapse-all
    ffi-qt-tree-widget-clear
    ffi-qt-tree-widget-on-current-item-changed
    ffi-qt-tree-widget-on-item-double-clicked
    ffi-qt-tree-widget-on-item-expanded ffi-qt-tree-widget-on-item-collapsed

    ;; Tree Widget Item
    ffi-qt-tree-item-create ffi-qt-tree-item-set-text ffi-qt-tree-item-text
    ffi-qt-tree-item-add-child ffi-qt-tree-item-child-count
    ffi-qt-tree-item-child ffi-qt-tree-item-parent
    ffi-qt-tree-item-set-expanded ffi-qt-tree-item-is-expanded

    ;; List Widget
    ffi-qt-list-widget-create ffi-qt-list-widget-add-item
    ffi-qt-list-widget-insert-item ffi-qt-list-widget-remove-item
    ffi-qt-list-widget-current-row ffi-qt-list-widget-set-current-row
    ffi-qt-list-widget-item-text ffi-qt-list-widget-count
    ffi-qt-list-widget-clear
    ffi-qt-list-widget-set-item-data ffi-qt-list-widget-item-data
    ffi-qt-list-widget-on-current-row-changed
    ffi-qt-list-widget-on-item-double-clicked

    ;; Table Widget
    ffi-qt-table-widget-create ffi-qt-table-widget-set-item
    ffi-qt-table-widget-item-text
    ffi-qt-table-widget-set-horizontal-header-item
    ffi-qt-table-widget-set-vertical-header-item
    ffi-qt-table-widget-set-row-count ffi-qt-table-widget-set-column-count
    ffi-qt-table-widget-row-count ffi-qt-table-widget-column-count
    ffi-qt-table-widget-current-row ffi-qt-table-widget-current-column
    ffi-qt-table-widget-clear ffi-qt-table-widget-on-cell-clicked

    ;; Tab Widget
    ffi-qt-tab-widget-create ffi-qt-tab-widget-add-tab
    ffi-qt-tab-widget-set-current-index ffi-qt-tab-widget-current-index
    ffi-qt-tab-widget-count ffi-qt-tab-widget-set-tab-text
    ffi-qt-tab-widget-on-current-changed

    ;; Progress Bar
    ffi-qt-progress-bar-create ffi-qt-progress-bar-set-value
    ffi-qt-progress-bar-value ffi-qt-progress-bar-set-range
    ffi-qt-progress-bar-set-format

    ;; Slider
    ffi-qt-slider-create ffi-qt-slider-set-value ffi-qt-slider-value
    ffi-qt-slider-set-range ffi-qt-slider-set-single-step
    ffi-qt-slider-set-tick-interval ffi-qt-slider-set-tick-position
    ffi-qt-slider-on-value-changed

    ;; Window State
    ffi-qt-widget-show-minimized ffi-qt-widget-show-maximized
    ffi-qt-widget-show-fullscreen ffi-qt-widget-show-normal
    ffi-qt-widget-window-state ffi-qt-widget-move
    ffi-qt-widget-x ffi-qt-widget-y ffi-qt-widget-width ffi-qt-widget-height
    ffi-qt-widget-set-focus

    ;; App Style Sheet
    ffi-qt-app-set-style-sheet

    ;; Scroll Area
    ffi-qt-scroll-area-create ffi-qt-scroll-area-set-widget
    ffi-qt-scroll-area-set-widget-resizable
    ffi-qt-scroll-area-set-horizontal-scrollbar-policy
    ffi-qt-scroll-area-set-vertical-scrollbar-policy

    ;; Splitter
    ffi-qt-splitter-create ffi-qt-splitter-add-widget
    ffi-qt-splitter-insert-widget ffi-qt-splitter-index-of
    ffi-qt-splitter-widget ffi-qt-splitter-count
    ffi-qt-splitter-set-sizes-2 ffi-qt-splitter-set-sizes-3 ffi-qt-splitter-set-sizes-4 ffi-qt-splitter-size-at
    ffi-qt-splitter-set-stretch-factor ffi-qt-splitter-set-handle-width
    ffi-qt-splitter-set-collapsible ffi-qt-splitter-is-collapsible
    ffi-qt-splitter-set-orientation

    ;; Keyboard Events
    ffi-qt-install-key-handler ffi-qt-install-key-handler-consuming
    ffi-qt-last-key-code ffi-qt-last-key-modifiers ffi-qt-last-key-text
    ffi-qt-last-key-autorepeat ffi-qt-last-key-widget
    ffi-qt-send-key-event

    ;; Pixmap
    ffi-qt-pixmap-load ffi-qt-pixmap-width ffi-qt-pixmap-height
    ffi-qt-pixmap-is-null ffi-qt-pixmap-scaled ffi-qt-pixmap-destroy
    ffi-qt-pixmap-save ffi-qt-widget-grab
    ffi-qt-label-set-pixmap

    ;; Icon
    ffi-qt-icon-create ffi-qt-icon-create-from-pixmap
    ffi-qt-icon-is-null ffi-qt-icon-destroy
    ffi-qt-push-button-set-icon ffi-qt-action-set-icon
    ffi-qt-widget-set-window-icon

    ;; Radio Button
    ffi-qt-radio-button-create ffi-qt-radio-button-text
    ffi-qt-radio-button-set-text
    ffi-qt-radio-button-is-checked ffi-qt-radio-button-set-checked
    ffi-qt-radio-button-on-toggled

    ;; Button Group
    ffi-qt-button-group-create ffi-qt-button-group-add-button
    ffi-qt-button-group-remove-button ffi-qt-button-group-checked-id
    ffi-qt-button-group-set-exclusive ffi-qt-button-group-is-exclusive
    ffi-qt-button-group-on-clicked ffi-qt-button-group-destroy

    ;; Group Box
    ffi-qt-group-box-create ffi-qt-group-box-title
    ffi-qt-group-box-set-title
    ffi-qt-group-box-set-checkable ffi-qt-group-box-is-checkable
    ffi-qt-group-box-set-checked ffi-qt-group-box-is-checked
    ffi-qt-group-box-on-toggled

    ;; Font
    ffi-qt-font-create ffi-qt-font-family ffi-qt-font-point-size
    ffi-qt-font-is-bold ffi-qt-font-set-bold
    ffi-qt-font-is-italic ffi-qt-font-set-italic
    ffi-qt-font-destroy ffi-qt-widget-set-font ffi-qt-widget-font

    ;; Color
    ffi-qt-color-create ffi-qt-color-create-name
    ffi-qt-color-red ffi-qt-color-green ffi-qt-color-blue ffi-qt-color-alpha
    ffi-qt-color-name ffi-qt-color-is-valid ffi-qt-color-destroy

    ;; Constants
    ffi-qt-const-align-left ffi-qt-const-align-right ffi-qt-const-align-center
    ffi-qt-const-align-top ffi-qt-const-align-bottom
    ffi-qt-const-echo-normal ffi-qt-const-echo-no-echo
    ffi-qt-const-echo-password ffi-qt-const-echo-password-on-edit
    ffi-qt-const-horizontal ffi-qt-const-vertical
    ffi-qt-const-ticks-none ffi-qt-const-ticks-above
    ffi-qt-const-ticks-below ffi-qt-const-ticks-both-sides
    ffi-qt-const-window-no-state ffi-qt-const-window-minimized
    ffi-qt-const-window-maximized ffi-qt-const-window-full-screen
    ffi-qt-const-scrollbar-as-needed ffi-qt-const-scrollbar-always-off
    ffi-qt-const-scrollbar-always-on
    ffi-qt-const-cursor-arrow ffi-qt-const-cursor-cross
    ffi-qt-const-cursor-wait ffi-qt-const-cursor-ibeam
    ffi-qt-const-cursor-pointing-hand ffi-qt-const-cursor-forbidden
    ffi-qt-const-cursor-busy

    ;; Frame constants
    ffi-qt-const-frame-no-frame ffi-qt-const-frame-box ffi-qt-const-frame-panel
    ffi-qt-const-frame-win-panel ffi-qt-const-frame-hline ffi-qt-const-frame-vline
    ffi-qt-const-frame-styled-panel
    ffi-qt-const-frame-plain ffi-qt-const-frame-raised ffi-qt-const-frame-sunken

    ;; Button box constants
    ffi-qt-const-button-ok ffi-qt-const-button-cancel ffi-qt-const-button-apply
    ffi-qt-const-button-close ffi-qt-const-button-yes ffi-qt-const-button-no
    ffi-qt-const-button-reset ffi-qt-const-button-help ffi-qt-const-button-save
    ffi-qt-const-button-discard
    ffi-qt-const-button-role-invalid ffi-qt-const-button-role-accept
    ffi-qt-const-button-role-reject ffi-qt-const-button-role-destructive
    ffi-qt-const-button-role-action ffi-qt-const-button-role-help
    ffi-qt-const-button-role-yes ffi-qt-const-button-role-no
    ffi-qt-const-button-role-apply ffi-qt-const-button-role-reset

    ;; Day-of-week constants
    ffi-qt-const-monday ffi-qt-const-tuesday ffi-qt-const-wednesday
    ffi-qt-const-thursday ffi-qt-const-friday ffi-qt-const-saturday ffi-qt-const-sunday

    ;; Settings constants
    ffi-qt-const-settings-native ffi-qt-const-settings-ini

    ;; Completer constants
    ffi-qt-const-completer-popup ffi-qt-const-completer-inline
    ffi-qt-const-completer-unfiltered-popup

    ;; Case sensitivity
    ffi-qt-const-case-insensitive ffi-qt-const-case-sensitive

    ;; Match filter mode
    ffi-qt-const-match-starts-with ffi-qt-const-match-contains
    ffi-qt-const-match-ends-with

    ;; Validator state
    ffi-qt-const-validator-invalid ffi-qt-const-validator-intermediate
    ffi-qt-const-validator-acceptable

    ;; PlainTextEdit wrap
    ffi-qt-const-plain-no-wrap ffi-qt-const-plain-widget-wrap

    ;; ToolButton constants
    ffi-qt-const-delayed-popup ffi-qt-const-menu-button-popup ffi-qt-const-instant-popup
    ffi-qt-const-no-arrow ffi-qt-const-up-arrow ffi-qt-const-down-arrow
    ffi-qt-const-left-arrow ffi-qt-const-right-arrow
    ffi-qt-const-tool-button-icon-only ffi-qt-const-tool-button-text-only
    ffi-qt-const-tool-button-text-beside-icon ffi-qt-const-tool-button-text-under-icon

    ;; Size policy
    ffi-qt-const-size-fixed ffi-qt-const-size-minimum ffi-qt-const-size-minimum-expanding
    ffi-qt-const-size-maximum ffi-qt-const-size-preferred ffi-qt-const-size-expanding
    ffi-qt-const-size-ignored

    ;; Graphics constants
    ffi-qt-const-item-movable ffi-qt-const-item-selectable ffi-qt-const-item-focusable
    ffi-qt-const-drag-none ffi-qt-const-drag-scroll ffi-qt-const-drag-rubber-band
    ffi-qt-const-render-antialiasing ffi-qt-const-render-smooth-pixmap
    ffi-qt-const-render-text-antialiasing

    ;; Process state
    ffi-qt-const-process-not-running ffi-qt-const-process-starting
    ffi-qt-const-process-running

    ;; MDI view mode
    ffi-qt-const-mdi-subwindow ffi-qt-const-mdi-tabbed

    ;; LCD constants
    ffi-qt-const-lcd-dec ffi-qt-const-lcd-hex ffi-qt-const-lcd-oct ffi-qt-const-lcd-bin
    ffi-qt-const-lcd-outline ffi-qt-const-lcd-filled ffi-qt-const-lcd-flat

    ;; Dir filter flags
    ffi-qt-const-dir-dirs ffi-qt-const-dir-files ffi-qt-const-dir-hidden
    ffi-qt-const-dir-no-dot-and-dot-dot

    ;; Cursor movement
    ffi-qt-const-cursor-no-move ffi-qt-const-cursor-start ffi-qt-const-cursor-up
    ffi-qt-const-cursor-start-of-line ffi-qt-const-cursor-start-of-block
    ffi-qt-const-cursor-previous-char ffi-qt-const-cursor-previous-block
    ffi-qt-const-cursor-end-of-line ffi-qt-const-cursor-end-of-block
    ffi-qt-const-cursor-next-char ffi-qt-const-cursor-next-block
    ffi-qt-const-cursor-end ffi-qt-const-cursor-down
    ffi-qt-const-cursor-left ffi-qt-const-cursor-word-left
    ffi-qt-const-cursor-next-word ffi-qt-const-cursor-right
    ffi-qt-const-cursor-word-right ffi-qt-const-cursor-previous-word
    ffi-qt-const-move-anchor ffi-qt-const-keep-anchor

    ;; Find flags
    ffi-qt-const-find-backward ffi-qt-const-find-case-sensitive
    ffi-qt-const-find-whole-words

    ;; Dock area
    ffi-qt-const-dock-left ffi-qt-const-dock-right
    ffi-qt-const-dock-top ffi-qt-const-dock-bottom

    ;; Tray icon message type
    ffi-qt-const-tray-no-icon ffi-qt-const-tray-information
    ffi-qt-const-tray-warning ffi-qt-const-tray-critical

    ;; Key constants
    ffi-qt-const-key-escape ffi-qt-const-key-tab ffi-qt-const-key-backtab
    ffi-qt-const-key-backspace ffi-qt-const-key-return ffi-qt-const-key-enter
    ffi-qt-const-key-insert ffi-qt-const-key-delete ffi-qt-const-key-pause
    ffi-qt-const-key-home ffi-qt-const-key-end
    ffi-qt-const-key-left ffi-qt-const-key-up ffi-qt-const-key-right ffi-qt-const-key-down
    ffi-qt-const-key-page-up ffi-qt-const-key-page-down
    ffi-qt-const-key-f1 ffi-qt-const-key-f2 ffi-qt-const-key-f3 ffi-qt-const-key-f4
    ffi-qt-const-key-f5 ffi-qt-const-key-f6 ffi-qt-const-key-f7 ffi-qt-const-key-f8
    ffi-qt-const-key-f9 ffi-qt-const-key-f10 ffi-qt-const-key-f11 ffi-qt-const-key-f12
    ffi-qt-const-key-space

    ;; Keyboard modifiers
    ffi-qt-const-mod-none ffi-qt-const-mod-shift ffi-qt-const-mod-control
    ffi-qt-const-mod-alt ffi-qt-const-mod-meta

    ;; Selection mode/behavior
    ffi-qt-const-select-no-selection ffi-qt-const-select-single
    ffi-qt-const-select-multi ffi-qt-const-select-extended ffi-qt-const-select-contiguous
    ffi-qt-const-select-items ffi-qt-const-select-rows ffi-qt-const-select-columns

    ;; Edit triggers
    ffi-qt-const-no-edit-triggers ffi-qt-const-edit-double-click
    ffi-qt-const-edit-selected-click ffi-qt-const-edit-any-key-pressed
    ffi-qt-const-edit-all-triggers

    ;; Sort order
    ffi-qt-const-sort-ascending ffi-qt-const-sort-descending

    ;; Header resize mode
    ffi-qt-const-header-interactive ffi-qt-const-header-stretch
    ffi-qt-const-header-fixed ffi-qt-const-header-resize-to-contents

    ;; Check state
    ffi-qt-const-unchecked ffi-qt-const-partially-checked ffi-qt-const-checked

    ;; ListView flow
    ffi-qt-const-flow-top-to-bottom ffi-qt-const-flow-left-to-right

    ;; Font Dialog / Color Dialog
    ffi-qt-font-dialog-get-font ffi-qt-color-dialog-get-color

    ;; Stacked Widget
    ffi-qt-stacked-widget-create ffi-qt-stacked-widget-add-widget
    ffi-qt-stacked-widget-set-current-index ffi-qt-stacked-widget-current-index
    ffi-qt-stacked-widget-count ffi-qt-stacked-widget-on-current-changed
    ffi-qt-stacked-widget-set-current-widget

    ;; Dock Widget
    ffi-qt-dock-widget-create ffi-qt-dock-widget-set-widget
    ffi-qt-dock-widget-widget ffi-qt-dock-widget-set-title ffi-qt-dock-widget-title
    ffi-qt-dock-widget-set-floating ffi-qt-dock-widget-is-floating
    ffi-qt-main-window-add-dock-widget

    ;; System Tray Icon
    ffi-qt-system-tray-icon-create ffi-qt-system-tray-icon-set-tooltip
    ffi-qt-system-tray-icon-set-icon ffi-qt-system-tray-icon-show
    ffi-qt-system-tray-icon-hide ffi-qt-system-tray-icon-show-message
    ffi-qt-system-tray-icon-set-context-menu
    ffi-qt-system-tray-icon-on-activated
    ffi-qt-system-tray-icon-is-available ffi-qt-system-tray-icon-destroy

    ;; QPainter
    ffi-qt-pixmap-create-blank ffi-qt-pixmap-fill
    ffi-qt-painter-create ffi-qt-painter-end ffi-qt-painter-destroy
    ffi-qt-painter-set-pen-color ffi-qt-painter-set-pen-width
    ffi-qt-painter-set-brush-color ffi-qt-painter-set-font-painter
    ffi-qt-painter-set-antialiasing
    ffi-qt-painter-draw-line ffi-qt-painter-draw-rect ffi-qt-painter-fill-rect
    ffi-qt-painter-draw-ellipse ffi-qt-painter-draw-text ffi-qt-painter-draw-text-rect
    ffi-qt-painter-draw-pixmap ffi-qt-painter-draw-point ffi-qt-painter-draw-arc
    ffi-qt-painter-save ffi-qt-painter-restore
    ffi-qt-painter-translate ffi-qt-painter-rotate ffi-qt-painter-scale

    ;; Drag and Drop
    ffi-qt-widget-set-accept-drops
    ffi-qt-drop-filter-install ffi-qt-drop-filter-last-text
    ffi-qt-drop-filter-destroy ffi-qt-drag-text

    ;; Double Spin Box
    ffi-qt-double-spin-box-create ffi-qt-double-spin-box-set-value
    ffi-qt-double-spin-box-value ffi-qt-double-spin-box-set-range
    ffi-qt-double-spin-box-set-single-step ffi-qt-double-spin-box-set-decimals
    ffi-qt-double-spin-box-decimals ffi-qt-double-spin-box-set-prefix
    ffi-qt-double-spin-box-set-suffix ffi-qt-double-spin-box-on-value-changed

    ;; Date Edit
    ffi-qt-date-edit-create ffi-qt-date-edit-set-date
    ffi-qt-date-edit-year ffi-qt-date-edit-month ffi-qt-date-edit-day
    ffi-qt-date-edit-date-string ffi-qt-date-edit-set-minimum-date
    ffi-qt-date-edit-set-maximum-date ffi-qt-date-edit-set-calendar-popup
    ffi-qt-date-edit-set-display-format ffi-qt-date-edit-on-date-changed

    ;; Time Edit
    ffi-qt-time-edit-create ffi-qt-time-edit-set-time
    ffi-qt-time-edit-hour ffi-qt-time-edit-minute ffi-qt-time-edit-second
    ffi-qt-time-edit-time-string ffi-qt-time-edit-set-display-format
    ffi-qt-time-edit-on-time-changed

    ;; Frame
    ffi-qt-frame-create ffi-qt-frame-set-frame-shape ffi-qt-frame-frame-shape
    ffi-qt-frame-set-frame-shadow ffi-qt-frame-frame-shadow
    ffi-qt-frame-set-line-width ffi-qt-frame-line-width ffi-qt-frame-set-mid-line-width

    ;; Progress Dialog
    ffi-qt-progress-dialog-create ffi-qt-progress-dialog-set-value
    ffi-qt-progress-dialog-value ffi-qt-progress-dialog-set-range
    ffi-qt-progress-dialog-set-label-text ffi-qt-progress-dialog-was-canceled
    ffi-qt-progress-dialog-set-minimum-duration
    ffi-qt-progress-dialog-set-auto-close ffi-qt-progress-dialog-set-auto-reset
    ffi-qt-progress-dialog-reset ffi-qt-progress-dialog-on-canceled

    ;; Input Dialog
    ffi-qt-input-dialog-get-text ffi-qt-input-dialog-get-int
    ffi-qt-input-dialog-get-double ffi-qt-input-dialog-get-item
    ffi-qt-input-dialog-was-accepted

    ;; Form Layout
    ffi-qt-form-layout-create ffi-qt-form-layout-add-row
    ffi-qt-form-layout-add-row-widget ffi-qt-form-layout-add-spanning-widget
    ffi-qt-form-layout-row-count

    ;; Shortcut
    ffi-qt-shortcut-create ffi-qt-shortcut-set-key
    ffi-qt-shortcut-set-enabled ffi-qt-shortcut-is-enabled
    ffi-qt-shortcut-on-activated ffi-qt-shortcut-destroy

    ;; Text Browser
    ffi-qt-text-browser-create ffi-qt-text-browser-set-html
    ffi-qt-text-browser-set-plain-text ffi-qt-text-browser-plain-text
    ffi-qt-text-browser-set-open-external-links
    ffi-qt-text-browser-set-source ffi-qt-text-browser-source
    ffi-qt-text-browser-scroll-to-bottom ffi-qt-text-browser-append
    ffi-qt-text-browser-html ffi-qt-text-browser-on-anchor-clicked

    ;; Button Box
    ffi-qt-button-box-create ffi-qt-button-box-button
    ffi-qt-button-box-add-button
    ffi-qt-button-box-on-accepted ffi-qt-button-box-on-rejected
    ffi-qt-button-box-on-clicked

    ;; Calendar
    ffi-qt-calendar-create ffi-qt-calendar-set-selected-date
    ffi-qt-calendar-selected-year ffi-qt-calendar-selected-month
    ffi-qt-calendar-selected-day ffi-qt-calendar-selected-date-string
    ffi-qt-calendar-set-minimum-date ffi-qt-calendar-set-maximum-date
    ffi-qt-calendar-set-first-day-of-week ffi-qt-calendar-set-grid-visible
    ffi-qt-calendar-is-grid-visible ffi-qt-calendar-set-navigation-bar-visible
    ffi-qt-calendar-on-selection-changed ffi-qt-calendar-on-clicked

    ;; QSettings
    ffi-qt-settings-create ffi-qt-settings-create-file
    ffi-qt-settings-set-string ffi-qt-settings-value-string
    ffi-qt-settings-set-int ffi-qt-settings-value-int
    ffi-qt-settings-set-double ffi-qt-settings-value-double
    ffi-qt-settings-set-bool ffi-qt-settings-value-bool
    ffi-qt-settings-contains ffi-qt-settings-remove
    ffi-qt-settings-all-keys ffi-qt-settings-child-keys ffi-qt-settings-child-groups
    ffi-qt-settings-begin-group ffi-qt-settings-end-group ffi-qt-settings-group
    ffi-qt-settings-sync ffi-qt-settings-clear
    ffi-qt-settings-file-name ffi-qt-settings-is-writable ffi-qt-settings-destroy

    ;; QCompleter
    ffi-qt-completer-create ffi-qt-completer-set-model-strings
    ffi-qt-completer-set-case-sensitivity ffi-qt-completer-set-completion-mode
    ffi-qt-completer-set-filter-mode ffi-qt-completer-set-max-visible-items
    ffi-qt-completer-completion-count ffi-qt-completer-current-completion
    ffi-qt-completer-set-completion-prefix
    ffi-qt-completer-on-activated
    ffi-qt-line-edit-set-completer ffi-qt-completer-destroy

    ;; Tooltip / WhatsThis
    ffi-qt-tooltip-show-text ffi-qt-tooltip-hide-text ffi-qt-tooltip-is-visible
    ffi-qt-widget-tooltip ffi-qt-widget-set-whats-this ffi-qt-widget-whats-this

    ;; QStandardItemModel
    ffi-qt-standard-model-create ffi-qt-standard-model-destroy
    ffi-qt-standard-model-row-count ffi-qt-standard-model-column-count
    ffi-qt-standard-model-set-row-count ffi-qt-standard-model-set-column-count
    ffi-qt-standard-model-set-item ffi-qt-standard-model-item
    ffi-qt-standard-model-insert-row ffi-qt-standard-model-insert-column
    ffi-qt-standard-model-remove-row ffi-qt-standard-model-remove-column
    ffi-qt-standard-model-clear
    ffi-qt-standard-model-set-horizontal-header
    ffi-qt-standard-model-set-vertical-header

    ;; QStandardItem
    ffi-qt-standard-item-create ffi-qt-standard-item-text
    ffi-qt-standard-item-set-text
    ffi-qt-standard-item-tooltip ffi-qt-standard-item-set-tooltip
    ffi-qt-standard-item-set-editable ffi-qt-standard-item-is-editable
    ffi-qt-standard-item-set-enabled ffi-qt-standard-item-is-enabled
    ffi-qt-standard-item-set-selectable ffi-qt-standard-item-is-selectable
    ffi-qt-standard-item-set-checkable ffi-qt-standard-item-is-checkable
    ffi-qt-standard-item-set-check-state ffi-qt-standard-item-check-state
    ffi-qt-standard-item-set-icon
    ffi-qt-standard-item-append-row ffi-qt-standard-item-row-count
    ffi-qt-standard-item-column-count ffi-qt-standard-item-child

    ;; QStringListModel
    ffi-qt-string-list-model-create ffi-qt-string-list-model-destroy
    ffi-qt-string-list-model-set-strings ffi-qt-string-list-model-strings
    ffi-qt-string-list-model-row-count

    ;; Views (common)
    ffi-qt-view-set-model ffi-qt-view-set-selection-mode
    ffi-qt-view-set-selection-behavior ffi-qt-view-set-alternating-row-colors
    ffi-qt-view-set-sorting-enabled ffi-qt-view-set-edit-triggers

    ;; QListView
    ffi-qt-list-view-create ffi-qt-list-view-set-flow

    ;; QTableView
    ffi-qt-table-view-create ffi-qt-table-view-set-column-width
    ffi-qt-table-view-set-row-height
    ffi-qt-table-view-hide-column ffi-qt-table-view-show-column
    ffi-qt-table-view-hide-row ffi-qt-table-view-show-row
    ffi-qt-table-view-resize-columns-to-contents
    ffi-qt-table-view-resize-rows-to-contents

    ;; QTreeView
    ffi-qt-tree-view-create ffi-qt-tree-view-expand-all ffi-qt-tree-view-collapse-all
    ffi-qt-tree-view-set-indentation ffi-qt-tree-view-indentation
    ffi-qt-tree-view-set-root-is-decorated ffi-qt-tree-view-set-header-hidden
    ffi-qt-tree-view-set-column-width

    ;; QHeaderView (via view)
    ffi-qt-view-header-set-stretch-last-section
    ffi-qt-view-header-set-section-resize-mode
    ffi-qt-view-header-hide ffi-qt-view-header-show
    ffi-qt-view-header-set-default-section-size

    ;; QSortFilterProxyModel
    ffi-qt-sort-filter-proxy-create ffi-qt-sort-filter-proxy-destroy
    ffi-qt-sort-filter-proxy-set-source-model
    ffi-qt-sort-filter-proxy-set-filter-regex
    ffi-qt-sort-filter-proxy-set-filter-column
    ffi-qt-sort-filter-proxy-set-filter-case-sensitivity
    ffi-qt-sort-filter-proxy-set-filter-role
    ffi-qt-sort-filter-proxy-sort ffi-qt-sort-filter-proxy-set-sort-role
    ffi-qt-sort-filter-proxy-set-dynamic-sort-filter
    ffi-qt-sort-filter-proxy-invalidate-filter
    ffi-qt-sort-filter-proxy-row-count

    ;; View signals + selection
    ffi-qt-view-on-clicked ffi-qt-view-on-double-clicked
    ffi-qt-view-on-activated ffi-qt-view-on-selection-changed
    ffi-qt-view-last-clicked-row ffi-qt-view-last-clicked-col
    ffi-qt-view-selected-rows ffi-qt-view-current-row

    ;; Validators
    ffi-qt-int-validator-create ffi-qt-double-validator-create
    ffi-qt-regex-validator-create ffi-qt-validator-destroy
    ffi-qt-validator-validate ffi-qt-line-edit-set-validator
    ffi-qt-line-edit-has-acceptable-input

    ;; QPlainTextEdit
    ffi-qt-plain-text-edit-create ffi-qt-plain-text-edit-set-text
    ffi-qt-plain-text-edit-text ffi-qt-plain-text-edit-append
    ffi-qt-plain-text-edit-clear ffi-qt-plain-text-edit-set-read-only
    ffi-qt-plain-text-edit-is-read-only ffi-qt-plain-text-edit-set-placeholder
    ffi-qt-plain-text-edit-line-count ffi-qt-plain-text-edit-set-max-block-count
    ffi-qt-plain-text-edit-cursor-line ffi-qt-plain-text-edit-cursor-column
    ffi-qt-plain-text-edit-set-line-wrap
    ffi-qt-plain-text-edit-on-text-changed
    ;; Editor extensions
    ffi-qt-plain-text-edit-cursor-position ffi-qt-plain-text-edit-set-cursor-position
    ffi-qt-plain-text-edit-move-cursor
    ffi-qt-plain-text-edit-select-all ffi-qt-plain-text-edit-selected-text
    ffi-qt-plain-text-edit-selection-start ffi-qt-plain-text-edit-selection-end
    ffi-qt-plain-text-edit-set-selection ffi-qt-plain-text-edit-has-selection
    ffi-qt-plain-text-edit-insert-text ffi-qt-plain-text-edit-remove-selected-text
    ffi-qt-plain-text-edit-undo ffi-qt-plain-text-edit-redo
    ffi-qt-plain-text-edit-can-undo
    ffi-qt-plain-text-edit-cut ffi-qt-plain-text-edit-copy ffi-qt-plain-text-edit-paste
    ffi-qt-plain-text-edit-text-length ffi-qt-plain-text-edit-text-range
    ffi-qt-plain-text-edit-line-from-position ffi-qt-plain-text-edit-line-end-position
    ffi-qt-plain-text-edit-find-text
    ffi-qt-plain-text-edit-ensure-cursor-visible ffi-qt-plain-text-edit-center-cursor
    ffi-qt-text-document-create ffi-qt-plain-text-document-create
    ffi-qt-text-document-destroy
    ffi-qt-plain-text-edit-document ffi-qt-plain-text-edit-set-document
    ffi-qt-text-document-is-modified ffi-qt-text-document-set-modified

    ;; QToolButton
    ffi-qt-tool-button-create ffi-qt-tool-button-set-text ffi-qt-tool-button-text
    ffi-qt-tool-button-set-icon ffi-qt-tool-button-set-menu
    ffi-qt-tool-button-set-popup-mode ffi-qt-tool-button-set-auto-raise
    ffi-qt-tool-button-set-arrow-type ffi-qt-tool-button-set-tool-button-style
    ffi-qt-tool-button-on-clicked

    ;; Layout spacers / Size policy
    ffi-qt-layout-add-spacing
    ffi-qt-widget-set-size-policy ffi-qt-layout-set-stretch-factor

    ;; Graphics Scene
    ffi-qt-graphics-scene-create ffi-qt-graphics-scene-add-rect
    ffi-qt-graphics-scene-add-ellipse ffi-qt-graphics-scene-add-line
    ffi-qt-graphics-scene-add-text ffi-qt-graphics-scene-add-pixmap
    ffi-qt-graphics-scene-remove-item ffi-qt-graphics-scene-clear
    ffi-qt-graphics-scene-items-count ffi-qt-graphics-scene-set-background
    ffi-qt-graphics-scene-destroy

    ;; Graphics View
    ffi-qt-graphics-view-create ffi-qt-graphics-view-set-render-hint
    ffi-qt-graphics-view-set-drag-mode ffi-qt-graphics-view-fit-in-view
    ffi-qt-graphics-view-scale ffi-qt-graphics-view-center-on

    ;; Graphics Item
    ffi-qt-graphics-item-set-pos ffi-qt-graphics-item-x ffi-qt-graphics-item-y
    ffi-qt-graphics-item-set-pen ffi-qt-graphics-item-set-brush
    ffi-qt-graphics-item-set-flags ffi-qt-graphics-item-set-tooltip
    ffi-qt-graphics-item-set-zvalue ffi-qt-graphics-item-zvalue
    ffi-qt-graphics-item-set-rotation ffi-qt-graphics-item-set-scale
    ffi-qt-graphics-item-set-visible

    ;; Paint Widget
    ffi-qt-paint-widget-create ffi-qt-paint-widget-on-paint
    ffi-qt-paint-widget-painter ffi-qt-paint-widget-update
    ffi-qt-paint-widget-width ffi-qt-paint-widget-height

    ;; QProcess
    ffi-qt-process-create ffi-qt-process-start ffi-qt-process-write
    ffi-qt-process-close-write ffi-qt-process-read-stdout ffi-qt-process-read-stderr
    ffi-qt-process-wait-for-finished ffi-qt-process-exit-code ffi-qt-process-state
    ffi-qt-process-kill ffi-qt-process-terminate
    ffi-qt-process-on-finished ffi-qt-process-on-ready-read ffi-qt-process-destroy

    ;; QWizard / QWizardPage
    ffi-qt-wizard-create ffi-qt-wizard-add-page ffi-qt-wizard-set-start-id
    ffi-qt-wizard-current-id ffi-qt-wizard-set-title ffi-qt-wizard-exec
    ffi-qt-wizard-page-create ffi-qt-wizard-page-set-title
    ffi-qt-wizard-page-set-subtitle ffi-qt-wizard-page-set-layout
    ffi-qt-wizard-on-current-changed

    ;; QMdiArea / QMdiSubWindow
    ffi-qt-mdi-area-create ffi-qt-mdi-area-add-sub-window
    ffi-qt-mdi-area-remove-sub-window ffi-qt-mdi-area-active-sub-window
    ffi-qt-mdi-area-sub-window-count ffi-qt-mdi-area-cascade ffi-qt-mdi-area-tile
    ffi-qt-mdi-area-set-view-mode ffi-qt-mdi-sub-window-set-title
    ffi-qt-mdi-area-on-sub-window-activated

    ;; QDial
    ffi-qt-dial-create ffi-qt-dial-set-value ffi-qt-dial-value
    ffi-qt-dial-set-range ffi-qt-dial-set-notches-visible ffi-qt-dial-set-wrapping
    ffi-qt-dial-on-value-changed

    ;; QLCDNumber
    ffi-qt-lcd-create ffi-qt-lcd-display-int ffi-qt-lcd-display-double
    ffi-qt-lcd-display-string ffi-qt-lcd-set-mode ffi-qt-lcd-set-segment-style

    ;; QToolBox
    ffi-qt-tool-box-create ffi-qt-tool-box-add-item
    ffi-qt-tool-box-set-current-index ffi-qt-tool-box-current-index
    ffi-qt-tool-box-count ffi-qt-tool-box-set-item-text
    ffi-qt-tool-box-on-current-changed

    ;; QUndoStack
    ffi-qt-undo-stack-create ffi-qt-undo-stack-push
    ffi-qt-undo-stack-undo ffi-qt-undo-stack-redo
    ffi-qt-undo-stack-can-undo ffi-qt-undo-stack-can-redo
    ffi-qt-undo-stack-undo-text ffi-qt-undo-stack-redo-text
    ffi-qt-undo-stack-clear
    ffi-qt-undo-stack-create-undo-action ffi-qt-undo-stack-create-redo-action
    ffi-qt-undo-stack-destroy

    ;; QFileSystemModel
    ffi-qt-file-system-model-create ffi-qt-file-system-model-set-root-path
    ffi-qt-file-system-model-set-filter ffi-qt-file-system-model-set-name-filters
    ffi-qt-file-system-model-file-path ffi-qt-tree-view-set-file-system-root
    ffi-qt-file-system-model-destroy

    ;; Signal disconnect
    ffi-qt-disconnect-all

    ;; QSyntaxHighlighter
    ffi-qt-syntax-highlighter-create ffi-qt-syntax-highlighter-destroy
    ffi-qt-syntax-highlighter-add-rule ffi-qt-syntax-highlighter-add-keywords
    ffi-qt-syntax-highlighter-add-multiline-rule
    ffi-qt-syntax-highlighter-clear-rules ffi-qt-syntax-highlighter-rehighlight

    ;; Line number area
    ffi-qt-line-number-area-create ffi-qt-line-number-area-destroy
    ffi-qt-line-number-area-set-visible
    ffi-qt-line-number-area-set-bg-color ffi-qt-line-number-area-set-fg-color

    ;; Extra selections
    ffi-qt-plain-text-edit-clear-extra-selections
    ffi-qt-plain-text-edit-add-extra-selection-line
    ffi-qt-plain-text-edit-add-extra-selection-range
    ffi-qt-plain-text-edit-apply-extra-selections

    ;; Completer on editor
    ffi-qt-completer-set-widget ffi-qt-completer-complete-rect

    ;; QScintilla
    ffi-qt-scintilla-create ffi-qt-scintilla-destroy
    ffi-qt-scintilla-send-message ffi-qt-scintilla-send-message-string
    ffi-qt-scintilla-receive-string
    ffi-qt-scintilla-set-text ffi-qt-scintilla-get-text ffi-qt-scintilla-get-text-length
    ffi-qt-scintilla-set-lexer-language ffi-qt-scintilla-get-lexer-language
    ffi-qt-scintilla-lexer-set-color ffi-qt-scintilla-lexer-set-paper ffi-qt-scintilla-lexer-set-font-attr
    ffi-qt-scintilla-set-read-only ffi-qt-scintilla-is-read-only
    ffi-qt-scintilla-set-margin-width ffi-qt-scintilla-set-margin-type
    ffi-qt-scintilla-set-focus
    ffi-qt-scintilla-on-text-changed ffi-qt-scintilla-on-char-added
    ffi-qt-scintilla-on-save-point-reached ffi-qt-scintilla-on-save-point-left
    ffi-qt-scintilla-on-margin-clicked ffi-qt-scintilla-on-modified)

  (import (chezscheme))

  ;; -----------------------------------------------------------------------
  ;; Load shared libraries
  ;; -----------------------------------------------------------------------

  (define shim-dir
    (or (getenv "CHEZ_QT_LIB")
        (let ([script-dir (getenv "CHEZ_QT_SCRIPT_DIR")])
          (and script-dir script-dir))
        "."))

  ;; In a static build (JEMACS_STATIC=1), both shims are compiled into the binary.
  ;; With -Wl,--export-dynamic all symbols are visible; no load-shared-object needed.
  ;; Chez's foreign-procedure resolves symbols from the binary's export table directly.
  (define static-build?
    (let ([v (getenv "JEMACS_STATIC")])
      (and v (not (string=? v "")) (not (string=? v "0")))))

  ;; libqt_shim.so comes from gerbil-qt's vendor/ dir — use LD_LIBRARY_PATH or explicit env var
  (define qt-shim-loaded
    (if static-build?
        #f   ; symbols already linked in; --export-dynamic makes them visible
        (load-shared-object
          (let ([qt-shim-dir (getenv "CHEZ_QT_SHIM_DIR")])
            (if qt-shim-dir
                (format "~a/libqt_shim.so" qt-shim-dir)
                "libqt_shim.so")))))

  (define chez-shim-loaded
    (if static-build?
        #f   ; qt_chez_shim.c compiled into binary
        (load-shared-object
          (format "~a/qt_chez_shim.so" shim-dir))))

  ;; -----------------------------------------------------------------------
  ;; Callback registration (Chez → C shim)
  ;; -----------------------------------------------------------------------

  (define ffi-set-void-callback
    (foreign-procedure "chez_qt_set_void_callback" (void*) void))

  (define ffi-set-string-callback
    (foreign-procedure "chez_qt_set_string_callback" (void*) void))

  (define ffi-set-int-callback
    (foreign-procedure "chez_qt_set_int_callback" (void*) void))

  (define ffi-set-bool-callback
    (foreign-procedure "chez_qt_set_bool_callback" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Constants — hardcoded from Qt header values
  ;; -----------------------------------------------------------------------

  ;; Alignment (Qt::AlignmentFlag)
  (define ffi-qt-const-align-left    #x0001)
  (define ffi-qt-const-align-right   #x0002)
  (define ffi-qt-const-align-center  #x0084)
  (define ffi-qt-const-align-top     #x0020)
  (define ffi-qt-const-align-bottom  #x0040)

  ;; Echo mode (QLineEdit::EchoMode)
  (define ffi-qt-const-echo-normal          0)
  (define ffi-qt-const-echo-no-echo         1)
  (define ffi-qt-const-echo-password        2)
  (define ffi-qt-const-echo-password-on-edit 3)

  ;; Orientation (Qt::Orientation)
  (define ffi-qt-const-horizontal  #x1)
  (define ffi-qt-const-vertical    #x2)

  ;; Slider tick position (QSlider::TickPosition)
  (define ffi-qt-const-ticks-none        0)
  (define ffi-qt-const-ticks-above       1)
  (define ffi-qt-const-ticks-below       2)
  (define ffi-qt-const-ticks-both-sides  3)

  ;; Window state (Qt::WindowState)
  (define ffi-qt-const-window-no-state    #x00)
  (define ffi-qt-const-window-minimized   #x01)
  (define ffi-qt-const-window-maximized   #x02)
  (define ffi-qt-const-window-full-screen #x04)

  ;; Scrollbar policy (Qt::ScrollBarPolicy)
  (define ffi-qt-const-scrollbar-as-needed  0)
  (define ffi-qt-const-scrollbar-always-off 1)
  (define ffi-qt-const-scrollbar-always-on  2)

  ;; Cursor shape (Qt::CursorShape)
  (define ffi-qt-const-cursor-arrow          0)
  (define ffi-qt-const-cursor-cross          2)
  (define ffi-qt-const-cursor-wait           3)
  (define ffi-qt-const-cursor-ibeam          4)
  (define ffi-qt-const-cursor-pointing-hand 13)
  (define ffi-qt-const-cursor-forbidden     14)
  (define ffi-qt-const-cursor-busy          16)

  ;; -----------------------------------------------------------------------
  ;; Application lifecycle
  ;; -----------------------------------------------------------------------

  (define ffi-qt-app-create
    (foreign-procedure "chez_qt_application_create" () void*))

  (define ffi-qt-app-exec
    (foreign-procedure "qt_application_exec" (void*) int))

  (define ffi-qt-app-quit
    (foreign-procedure "qt_application_quit" (void*) void))

  (define ffi-qt-app-process-events
    (foreign-procedure "qt_application_process_events" (void*) void))

  (define ffi-qt-app-destroy
    (foreign-procedure "qt_application_destroy" (void*) void))

  (define ffi-qt-app-is-running
    (foreign-procedure "qt_application_is_running" () int))

  (define ffi-qt-app-set-style-sheet
    (foreign-procedure "qt_application_set_style_sheet" (void* string) void))

  ;; -----------------------------------------------------------------------
  ;; Widget base
  ;; -----------------------------------------------------------------------

  (define ffi-qt-widget-create
    (foreign-procedure "qt_widget_create" (void*) void*))

  (define ffi-qt-widget-show
    (foreign-procedure "qt_widget_show" (void*) void))

  (define ffi-qt-widget-hide
    (foreign-procedure "qt_widget_hide" (void*) void))

  (define ffi-qt-widget-close
    (foreign-procedure "qt_widget_close" (void*) void))

  (define ffi-qt-widget-set-enabled
    (foreign-procedure "qt_widget_set_enabled" (void* int) void))

  (define ffi-qt-widget-is-enabled
    (foreign-procedure "qt_widget_is_enabled" (void*) int))

  (define ffi-qt-widget-set-visible
    (foreign-procedure "qt_widget_set_visible" (void* int) void))

  (define ffi-qt-widget-is-visible
    (foreign-procedure "qt_widget_is_visible" (void*) int))

  (define ffi-qt-widget-set-updates-enabled
    (foreign-procedure "qt_widget_set_updates_enabled" (void* int) void))

  (define ffi-qt-widget-set-fixed-size
    (foreign-procedure "qt_widget_set_fixed_size" (void* int int) void))

  (define ffi-qt-widget-set-minimum-size
    (foreign-procedure "qt_widget_set_minimum_size" (void* int int) void))

  (define ffi-qt-widget-set-maximum-size
    (foreign-procedure "qt_widget_set_maximum_size" (void* int int) void))

  (define ffi-qt-widget-set-minimum-width
    (foreign-procedure "qt_widget_set_minimum_width" (void* int) void))

  (define ffi-qt-widget-set-minimum-height
    (foreign-procedure "qt_widget_set_minimum_height" (void* int) void))

  (define ffi-qt-widget-set-maximum-width
    (foreign-procedure "qt_widget_set_maximum_width" (void* int) void))

  (define ffi-qt-widget-set-maximum-height
    (foreign-procedure "qt_widget_set_maximum_height" (void* int) void))

  (define ffi-qt-widget-set-cursor
    (foreign-procedure "qt_widget_set_cursor" (void* int) void))

  (define ffi-qt-widget-unset-cursor
    (foreign-procedure "qt_widget_unset_cursor" (void*) void))

  (define ffi-qt-widget-resize
    (foreign-procedure "qt_widget_resize" (void* int int) void))

  (define ffi-qt-widget-set-style-sheet
    (foreign-procedure "qt_widget_set_style_sheet" (void* string) void))
  (define ffi-qt-widget-set-attribute
    (foreign-procedure "qt_widget_set_attribute" (void* int int) void))

  (define ffi-qt-widget-set-tooltip
    (foreign-procedure "qt_widget_set_tooltip" (void* string) void))

  (define ffi-qt-widget-set-font-size
    (foreign-procedure "qt_widget_set_font_size" (void* int) void))

  (define ffi-qt-widget-destroy
    (foreign-procedure "qt_widget_destroy" (void*) void))

  ;; Window state
  (define ffi-qt-widget-show-minimized
    (foreign-procedure "qt_widget_show_minimized" (void*) void))
  (define ffi-qt-widget-show-maximized
    (foreign-procedure "qt_widget_show_maximized" (void*) void))
  (define ffi-qt-widget-show-fullscreen
    (foreign-procedure "qt_widget_show_fullscreen" (void*) void))
  (define ffi-qt-widget-show-normal
    (foreign-procedure "qt_widget_show_normal" (void*) void))
  (define ffi-qt-widget-window-state
    (foreign-procedure "qt_widget_window_state" (void*) int))
  (define ffi-qt-widget-move
    (foreign-procedure "qt_widget_move" (void* int int) void))
  (define ffi-qt-widget-x
    (foreign-procedure "qt_widget_x" (void*) int))
  (define ffi-qt-widget-y
    (foreign-procedure "qt_widget_y" (void*) int))
  (define ffi-qt-widget-width
    (foreign-procedure "qt_widget_width" (void*) int))
  (define ffi-qt-widget-height
    (foreign-procedure "qt_widget_height" (void*) int))
  (define ffi-qt-widget-set-focus
    (foreign-procedure "qt_widget_set_focus" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Main Window
  ;; -----------------------------------------------------------------------

  (define ffi-qt-main-window-create
    (foreign-procedure "qt_main_window_create" (void*) void*))

  (define ffi-qt-main-window-set-title
    (foreign-procedure "qt_main_window_set_title" (void* string) void))

  (define ffi-qt-main-window-set-central-widget
    (foreign-procedure "qt_main_window_set_central_widget" (void* void*) void))

  (define ffi-qt-main-window-menu-bar
    (foreign-procedure "qt_main_window_menu_bar" (void*) void*))

  (define ffi-qt-main-window-add-toolbar
    (foreign-procedure "qt_main_window_add_toolbar" (void* void*) void))

  (define ffi-qt-main-window-set-status-bar-text
    (foreign-procedure "qt_main_window_set_status_bar_text" (void* string) void))

  ;; -----------------------------------------------------------------------
  ;; Layouts
  ;; -----------------------------------------------------------------------

  (define ffi-qt-vbox-layout-create
    (foreign-procedure "qt_vbox_layout_create" (void*) void*))

  (define ffi-qt-hbox-layout-create
    (foreign-procedure "qt_hbox_layout_create" (void*) void*))

  (define ffi-qt-layout-add-widget
    (foreign-procedure "qt_layout_add_widget" (void* void*) void))

  (define ffi-qt-layout-add-stretch
    (foreign-procedure "qt_layout_add_stretch" (void* int) void))

  (define ffi-qt-layout-set-spacing
    (foreign-procedure "qt_layout_set_spacing" (void* int) void))

  (define ffi-qt-layout-set-margins
    (foreign-procedure "qt_layout_set_margins" (void* int int int int) void))

  ;; Grid Layout
  (define ffi-qt-grid-layout-create
    (foreign-procedure "qt_grid_layout_create" (void*) void*))
  (define ffi-qt-grid-layout-add-widget
    (foreign-procedure "qt_grid_layout_add_widget" (void* void* int int int int) void))
  (define ffi-qt-grid-layout-set-row-stretch
    (foreign-procedure "qt_grid_layout_set_row_stretch" (void* int int) void))
  (define ffi-qt-grid-layout-set-column-stretch
    (foreign-procedure "qt_grid_layout_set_column_stretch" (void* int int) void))
  (define ffi-qt-grid-layout-set-row-minimum-height
    (foreign-procedure "qt_grid_layout_set_row_minimum_height" (void* int int) void))
  (define ffi-qt-grid-layout-set-column-minimum-width
    (foreign-procedure "qt_grid_layout_set_column_minimum_width" (void* int int) void))

  ;; -----------------------------------------------------------------------
  ;; Labels
  ;; -----------------------------------------------------------------------

  (define ffi-qt-label-create
    (foreign-procedure "qt_label_create" (string void*) void*))

  (define ffi-qt-label-set-text
    (foreign-procedure "qt_label_set_text" (void* string) void))

  (define ffi-qt-label-text
    (foreign-procedure "qt_label_text" (void*) string))

  (define ffi-qt-label-set-alignment
    (foreign-procedure "qt_label_set_alignment" (void* int) void))

  (define ffi-qt-label-set-word-wrap
    (foreign-procedure "qt_label_set_word_wrap" (void* int) void))

  (define ffi-qt-label-set-pixmap
    (foreign-procedure "qt_label_set_pixmap" (void* void*) void))

  ;; -----------------------------------------------------------------------
  ;; Push Button
  ;; -----------------------------------------------------------------------

  (define ffi-qt-push-button-create
    (foreign-procedure "qt_push_button_create" (string void*) void*))

  (define ffi-qt-push-button-set-text
    (foreign-procedure "qt_push_button_set_text" (void* string) void))

  (define ffi-qt-push-button-text
    (foreign-procedure "qt_push_button_text" (void*) string))

  (define ffi-qt-push-button-on-clicked
    (foreign-procedure "chez_qt_push_button_on_clicked" (void* long) void))

  (define ffi-qt-push-button-set-icon
    (foreign-procedure "qt_push_button_set_icon" (void* void*) void))

  ;; -----------------------------------------------------------------------
  ;; Line Edit
  ;; -----------------------------------------------------------------------

  (define ffi-qt-line-edit-create
    (foreign-procedure "qt_line_edit_create" (void*) void*))

  (define ffi-qt-line-edit-set-text
    (foreign-procedure "qt_line_edit_set_text" (void* string) void))

  (define ffi-qt-line-edit-text
    (foreign-procedure "qt_line_edit_text" (void*) string))

  (define ffi-qt-line-edit-set-placeholder
    (foreign-procedure "qt_line_edit_set_placeholder" (void* string) void))

  (define ffi-qt-line-edit-set-read-only
    (foreign-procedure "qt_line_edit_set_read_only" (void* int) void))

  (define ffi-qt-line-edit-set-echo-mode
    (foreign-procedure "qt_line_edit_set_echo_mode" (void* int) void))

  (define ffi-qt-line-edit-on-text-changed
    (foreign-procedure "chez_qt_line_edit_on_text_changed" (void* long) void))

  (define ffi-qt-line-edit-on-return-pressed
    (foreign-procedure "chez_qt_line_edit_on_return_pressed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Check Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-check-box-create
    (foreign-procedure "qt_check_box_create" (string void*) void*))

  (define ffi-qt-check-box-set-text
    (foreign-procedure "qt_check_box_set_text" (void* string) void))

  (define ffi-qt-check-box-set-checked
    (foreign-procedure "qt_check_box_set_checked" (void* int) void))

  (define ffi-qt-check-box-is-checked
    (foreign-procedure "qt_check_box_is_checked" (void*) int))

  (define ffi-qt-check-box-on-toggled
    (foreign-procedure "chez_qt_check_box_on_toggled" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Combo Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-combo-box-create
    (foreign-procedure "qt_combo_box_create" (void*) void*))

  (define ffi-qt-combo-box-add-item
    (foreign-procedure "qt_combo_box_add_item" (void* string) void))

  (define ffi-qt-combo-box-set-current-index
    (foreign-procedure "qt_combo_box_set_current_index" (void* int) void))

  (define ffi-qt-combo-box-current-index
    (foreign-procedure "qt_combo_box_current_index" (void*) int))

  (define ffi-qt-combo-box-current-text
    (foreign-procedure "qt_combo_box_current_text" (void*) string))

  (define ffi-qt-combo-box-count
    (foreign-procedure "qt_combo_box_count" (void*) int))

  (define ffi-qt-combo-box-clear
    (foreign-procedure "qt_combo_box_clear" (void*) void))

  (define ffi-qt-combo-box-on-current-index-changed
    (foreign-procedure "chez_qt_combo_box_on_current_index_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Text Edit
  ;; -----------------------------------------------------------------------

  (define ffi-qt-text-edit-create
    (foreign-procedure "qt_text_edit_create" (void*) void*))

  (define ffi-qt-text-edit-set-text
    (foreign-procedure "qt_text_edit_set_text" (void* string) void))

  (define ffi-qt-text-edit-text
    (foreign-procedure "qt_text_edit_text" (void*) string))

  (define ffi-qt-text-edit-set-placeholder
    (foreign-procedure "qt_text_edit_set_placeholder" (void* string) void))

  (define ffi-qt-text-edit-set-read-only
    (foreign-procedure "qt_text_edit_set_read_only" (void* int) void))

  (define ffi-qt-text-edit-append
    (foreign-procedure "qt_text_edit_append" (void* string) void))

  (define ffi-qt-text-edit-clear
    (foreign-procedure "qt_text_edit_clear" (void*) void))

  (define ffi-qt-text-edit-scroll-to-bottom
    (foreign-procedure "qt_text_edit_scroll_to_bottom" (void*) void))

  (define ffi-qt-text-edit-html
    (foreign-procedure "qt_text_edit_html" (void*) string))

  (define ffi-qt-text-edit-on-text-changed
    (foreign-procedure "chez_qt_text_edit_on_text_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Spin Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-spin-box-create
    (foreign-procedure "qt_spin_box_create" (void*) void*))

  (define ffi-qt-spin-box-set-value
    (foreign-procedure "qt_spin_box_set_value" (void* int) void))

  (define ffi-qt-spin-box-value
    (foreign-procedure "qt_spin_box_value" (void*) int))

  (define ffi-qt-spin-box-set-range
    (foreign-procedure "qt_spin_box_set_range" (void* int int) void))

  (define ffi-qt-spin-box-set-single-step
    (foreign-procedure "qt_spin_box_set_single_step" (void* int) void))

  (define ffi-qt-spin-box-set-prefix
    (foreign-procedure "qt_spin_box_set_prefix" (void* string) void))

  (define ffi-qt-spin-box-set-suffix
    (foreign-procedure "qt_spin_box_set_suffix" (void* string) void))

  (define ffi-qt-spin-box-on-value-changed
    (foreign-procedure "chez_qt_spin_box_on_value_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Dialog
  ;; -----------------------------------------------------------------------

  (define ffi-qt-dialog-create
    (foreign-procedure "qt_dialog_create" (void*) void*))

  (define ffi-qt-dialog-exec
    (foreign-procedure "qt_dialog_exec" (void*) int))

  (define ffi-qt-dialog-accept
    (foreign-procedure "qt_dialog_accept" (void*) void))

  (define ffi-qt-dialog-reject
    (foreign-procedure "qt_dialog_reject" (void*) void))

  (define ffi-qt-dialog-set-title
    (foreign-procedure "qt_dialog_set_title" (void* string) void))

  ;; -----------------------------------------------------------------------
  ;; Message Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-message-box-information
    (foreign-procedure "qt_message_box_information" (void* string string) int))

  (define ffi-qt-message-box-warning
    (foreign-procedure "qt_message_box_warning" (void* string string) int))

  (define ffi-qt-message-box-question
    (foreign-procedure "qt_message_box_question" (void* string string) int))

  (define ffi-qt-message-box-critical
    (foreign-procedure "qt_message_box_critical" (void* string string) int))

  ;; -----------------------------------------------------------------------
  ;; File Dialog
  ;; -----------------------------------------------------------------------

  (define ffi-qt-file-dialog-open-file
    (foreign-procedure "qt_file_dialog_open_file" (void* string string string) string))

  (define ffi-qt-file-dialog-save-file
    (foreign-procedure "qt_file_dialog_save_file" (void* string string string) string))

  (define ffi-qt-file-dialog-open-directory
    (foreign-procedure "qt_file_dialog_open_directory" (void* string string) string))

  ;; -----------------------------------------------------------------------
  ;; Menu
  ;; -----------------------------------------------------------------------

  (define ffi-qt-menu-bar-add-menu
    (foreign-procedure "qt_menu_bar_add_menu" (void* string) void*))

  (define ffi-qt-menu-add-menu
    (foreign-procedure "qt_menu_add_menu" (void* string) void*))

  (define ffi-qt-menu-add-action
    (foreign-procedure "qt_menu_add_action" (void* void*) void))

  (define ffi-qt-menu-add-separator
    (foreign-procedure "qt_menu_add_separator" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Action
  ;; -----------------------------------------------------------------------

  (define ffi-qt-action-create
    (foreign-procedure "qt_action_create" (string void*) void*))

  (define ffi-qt-action-set-text
    (foreign-procedure "qt_action_set_text" (void* string) void))

  (define ffi-qt-action-text
    (foreign-procedure "qt_action_text" (void*) string))

  (define ffi-qt-action-set-shortcut
    (foreign-procedure "qt_action_set_shortcut" (void* string) void))

  (define ffi-qt-action-set-enabled
    (foreign-procedure "qt_action_set_enabled" (void* int) void))

  (define ffi-qt-action-is-enabled
    (foreign-procedure "qt_action_is_enabled" (void*) int))

  (define ffi-qt-action-set-checkable
    (foreign-procedure "qt_action_set_checkable" (void* int) void))

  (define ffi-qt-action-is-checkable
    (foreign-procedure "qt_action_is_checkable" (void*) int))

  (define ffi-qt-action-set-checked
    (foreign-procedure "qt_action_set_checked" (void* int) void))

  (define ffi-qt-action-is-checked
    (foreign-procedure "qt_action_is_checked" (void*) int))

  (define ffi-qt-action-set-tooltip
    (foreign-procedure "qt_action_set_tooltip" (void* string) void))

  (define ffi-qt-action-set-status-tip
    (foreign-procedure "qt_action_set_status_tip" (void* string) void))

  (define ffi-qt-action-on-triggered
    (foreign-procedure "chez_qt_action_on_triggered" (void* long) void))

  (define ffi-qt-action-on-toggled
    (foreign-procedure "chez_qt_action_on_toggled" (void* long) void))

  (define ffi-qt-action-set-icon
    (foreign-procedure "qt_action_set_icon" (void* void*) void))

  ;; -----------------------------------------------------------------------
  ;; Toolbar
  ;; -----------------------------------------------------------------------

  (define ffi-qt-toolbar-create
    (foreign-procedure "qt_toolbar_create" (string void*) void*))

  (define ffi-qt-toolbar-add-action
    (foreign-procedure "qt_toolbar_add_action" (void* void*) void))

  (define ffi-qt-toolbar-add-separator
    (foreign-procedure "qt_toolbar_add_separator" (void*) void))

  (define ffi-qt-toolbar-add-widget
    (foreign-procedure "qt_toolbar_add_widget" (void* void*) void))

  (define ffi-qt-toolbar-set-movable
    (foreign-procedure "qt_toolbar_set_movable" (void* int) void))

  (define ffi-qt-toolbar-set-icon-size
    (foreign-procedure "qt_toolbar_set_icon_size" (void* int int) void))

  ;; -----------------------------------------------------------------------
  ;; Timer
  ;; -----------------------------------------------------------------------

  (define ffi-qt-timer-create
    (foreign-procedure "qt_timer_create" () void*))
  (define ffi-qt-timer-start
    (foreign-procedure "qt_timer_start" (void* int) void))
  (define ffi-qt-timer-stop
    (foreign-procedure "qt_timer_stop" (void*) void))
  (define ffi-qt-timer-set-single-shot
    (foreign-procedure "qt_timer_set_single_shot" (void* int) void))
  (define ffi-qt-timer-is-active
    (foreign-procedure "qt_timer_is_active" (void*) int))
  (define ffi-qt-timer-interval
    (foreign-procedure "qt_timer_interval" (void*) int))
  (define ffi-qt-timer-set-interval
    (foreign-procedure "qt_timer_set_interval" (void* int) void))
  (define ffi-qt-timer-on-timeout
    (foreign-procedure "chez_qt_timer_on_timeout" (void* long) void))
  (define ffi-qt-timer-single-shot
    (foreign-procedure "chez_qt_timer_single_shot" (int long) void))
  (define ffi-qt-timer-destroy
    (foreign-procedure "qt_timer_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Clipboard
  ;; -----------------------------------------------------------------------

  (define ffi-qt-clipboard-text
    (foreign-procedure "qt_clipboard_text" (void*) string))
  (define ffi-qt-clipboard-set-text
    (foreign-procedure "qt_clipboard_set_text" (void* string) void))
  (define ffi-qt-clipboard-on-changed
    (foreign-procedure "chez_qt_clipboard_on_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Tree Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-tree-widget-create
    (foreign-procedure "qt_tree_widget_create" (void*) void*))
  (define ffi-qt-tree-widget-set-column-count
    (foreign-procedure "qt_tree_widget_set_column_count" (void* int) void))
  (define ffi-qt-tree-widget-column-count
    (foreign-procedure "qt_tree_widget_column_count" (void*) int))
  (define ffi-qt-tree-widget-set-header-label
    (foreign-procedure "qt_tree_widget_set_header_label" (void* string) void))
  (define ffi-qt-tree-widget-set-header-item-text
    (foreign-procedure "qt_tree_widget_set_header_item_text" (void* int string) void))
  (define ffi-qt-tree-widget-add-top-level-item
    (foreign-procedure "qt_tree_widget_add_top_level_item" (void* void*) void))
  (define ffi-qt-tree-widget-top-level-item-count
    (foreign-procedure "qt_tree_widget_top_level_item_count" (void*) int))
  (define ffi-qt-tree-widget-top-level-item
    (foreign-procedure "qt_tree_widget_top_level_item" (void* int) void*))
  (define ffi-qt-tree-widget-current-item
    (foreign-procedure "qt_tree_widget_current_item" (void*) void*))
  (define ffi-qt-tree-widget-set-current-item
    (foreign-procedure "qt_tree_widget_set_current_item" (void* void*) void))
  (define ffi-qt-tree-widget-expand-item
    (foreign-procedure "qt_tree_widget_expand_item" (void* void*) void))
  (define ffi-qt-tree-widget-collapse-item
    (foreign-procedure "qt_tree_widget_collapse_item" (void* void*) void))
  (define ffi-qt-tree-widget-expand-all
    (foreign-procedure "qt_tree_widget_expand_all" (void*) void))
  (define ffi-qt-tree-widget-collapse-all
    (foreign-procedure "qt_tree_widget_collapse_all" (void*) void))
  (define ffi-qt-tree-widget-clear
    (foreign-procedure "qt_tree_widget_clear" (void*) void))
  (define ffi-qt-tree-widget-on-current-item-changed
    (foreign-procedure "chez_qt_tree_widget_on_current_item_changed" (void* long) void))
  (define ffi-qt-tree-widget-on-item-double-clicked
    (foreign-procedure "chez_qt_tree_widget_on_item_double_clicked" (void* long) void))
  (define ffi-qt-tree-widget-on-item-expanded
    (foreign-procedure "chez_qt_tree_widget_on_item_expanded" (void* long) void))
  (define ffi-qt-tree-widget-on-item-collapsed
    (foreign-procedure "chez_qt_tree_widget_on_item_collapsed" (void* long) void))

  ;; Tree Widget Item
  (define ffi-qt-tree-item-create
    (foreign-procedure "qt_tree_item_create" (string) void*))
  (define ffi-qt-tree-item-set-text
    (foreign-procedure "qt_tree_item_set_text" (void* int string) void))
  (define ffi-qt-tree-item-text
    (foreign-procedure "qt_tree_item_text" (void* int) string))
  (define ffi-qt-tree-item-add-child
    (foreign-procedure "qt_tree_item_add_child" (void* void*) void))
  (define ffi-qt-tree-item-child-count
    (foreign-procedure "qt_tree_item_child_count" (void*) int))
  (define ffi-qt-tree-item-child
    (foreign-procedure "qt_tree_item_child" (void* int) void*))
  (define ffi-qt-tree-item-parent
    (foreign-procedure "qt_tree_item_parent" (void*) void*))
  (define ffi-qt-tree-item-set-expanded
    (foreign-procedure "qt_tree_item_set_expanded" (void* int) void))
  (define ffi-qt-tree-item-is-expanded
    (foreign-procedure "qt_tree_item_is_expanded" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; List Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-list-widget-create
    (foreign-procedure "qt_list_widget_create" (void*) void*))
  (define ffi-qt-list-widget-add-item
    (foreign-procedure "qt_list_widget_add_item" (void* string) void))
  (define ffi-qt-list-widget-insert-item
    (foreign-procedure "qt_list_widget_insert_item" (void* int string) void))
  (define ffi-qt-list-widget-remove-item
    (foreign-procedure "qt_list_widget_remove_item" (void* int) void))
  (define ffi-qt-list-widget-current-row
    (foreign-procedure "qt_list_widget_current_row" (void*) int))
  (define ffi-qt-list-widget-set-current-row
    (foreign-procedure "qt_list_widget_set_current_row" (void* int) void))
  (define ffi-qt-list-widget-item-text
    (foreign-procedure "qt_list_widget_item_text" (void* int) string))
  (define ffi-qt-list-widget-count
    (foreign-procedure "qt_list_widget_count" (void*) int))
  (define ffi-qt-list-widget-clear
    (foreign-procedure "qt_list_widget_clear" (void*) void))
  (define ffi-qt-list-widget-set-item-data
    (foreign-procedure "qt_list_widget_set_item_data" (void* int string) void))
  (define ffi-qt-list-widget-item-data
    (foreign-procedure "qt_list_widget_item_data" (void* int) string))
  (define ffi-qt-list-widget-on-current-row-changed
    (foreign-procedure "chez_qt_list_widget_on_current_row_changed" (void* long) void))
  (define ffi-qt-list-widget-on-item-double-clicked
    (foreign-procedure "chez_qt_list_widget_on_item_double_clicked" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Table Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-table-widget-create
    (foreign-procedure "qt_table_widget_create" (int int void*) void*))
  (define ffi-qt-table-widget-set-item
    (foreign-procedure "qt_table_widget_set_item" (void* int int string) void))
  (define ffi-qt-table-widget-item-text
    (foreign-procedure "qt_table_widget_item_text" (void* int int) string))
  (define ffi-qt-table-widget-set-horizontal-header-item
    (foreign-procedure "qt_table_widget_set_horizontal_header_item" (void* int string) void))
  (define ffi-qt-table-widget-set-vertical-header-item
    (foreign-procedure "qt_table_widget_set_vertical_header_item" (void* int string) void))
  (define ffi-qt-table-widget-set-row-count
    (foreign-procedure "qt_table_widget_set_row_count" (void* int) void))
  (define ffi-qt-table-widget-set-column-count
    (foreign-procedure "qt_table_widget_set_column_count" (void* int) void))
  (define ffi-qt-table-widget-row-count
    (foreign-procedure "qt_table_widget_row_count" (void*) int))
  (define ffi-qt-table-widget-column-count
    (foreign-procedure "qt_table_widget_column_count" (void*) int))
  (define ffi-qt-table-widget-current-row
    (foreign-procedure "qt_table_widget_current_row" (void*) int))
  (define ffi-qt-table-widget-current-column
    (foreign-procedure "qt_table_widget_current_column" (void*) int))
  (define ffi-qt-table-widget-clear
    (foreign-procedure "qt_table_widget_clear" (void*) void))
  (define ffi-qt-table-widget-on-cell-clicked
    (foreign-procedure "chez_qt_table_widget_on_cell_clicked" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Tab Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-tab-widget-create
    (foreign-procedure "qt_tab_widget_create" (void*) void*))
  (define ffi-qt-tab-widget-add-tab
    (foreign-procedure "qt_tab_widget_add_tab" (void* void* string) void))
  (define ffi-qt-tab-widget-set-current-index
    (foreign-procedure "qt_tab_widget_set_current_index" (void* int) void))
  (define ffi-qt-tab-widget-current-index
    (foreign-procedure "qt_tab_widget_current_index" (void*) int))
  (define ffi-qt-tab-widget-count
    (foreign-procedure "qt_tab_widget_count" (void*) int))
  (define ffi-qt-tab-widget-set-tab-text
    (foreign-procedure "qt_tab_widget_set_tab_text" (void* int string) void))
  (define ffi-qt-tab-widget-on-current-changed
    (foreign-procedure "chez_qt_tab_widget_on_current_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Progress Bar
  ;; -----------------------------------------------------------------------

  (define ffi-qt-progress-bar-create
    (foreign-procedure "qt_progress_bar_create" (void*) void*))
  (define ffi-qt-progress-bar-set-value
    (foreign-procedure "qt_progress_bar_set_value" (void* int) void))
  (define ffi-qt-progress-bar-value
    (foreign-procedure "qt_progress_bar_value" (void*) int))
  (define ffi-qt-progress-bar-set-range
    (foreign-procedure "qt_progress_bar_set_range" (void* int int) void))
  (define ffi-qt-progress-bar-set-format
    (foreign-procedure "qt_progress_bar_set_format" (void* string) void))

  ;; -----------------------------------------------------------------------
  ;; Slider
  ;; -----------------------------------------------------------------------

  (define ffi-qt-slider-create
    (foreign-procedure "qt_slider_create" (int void*) void*))
  (define ffi-qt-slider-set-value
    (foreign-procedure "qt_slider_set_value" (void* int) void))
  (define ffi-qt-slider-value
    (foreign-procedure "qt_slider_value" (void*) int))
  (define ffi-qt-slider-set-range
    (foreign-procedure "qt_slider_set_range" (void* int int) void))
  (define ffi-qt-slider-set-single-step
    (foreign-procedure "qt_slider_set_single_step" (void* int) void))
  (define ffi-qt-slider-set-tick-interval
    (foreign-procedure "qt_slider_set_tick_interval" (void* int) void))
  (define ffi-qt-slider-set-tick-position
    (foreign-procedure "qt_slider_set_tick_position" (void* int) void))
  (define ffi-qt-slider-on-value-changed
    (foreign-procedure "chez_qt_slider_on_value_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Scroll Area
  ;; -----------------------------------------------------------------------

  (define ffi-qt-scroll-area-create
    (foreign-procedure "qt_scroll_area_create" (void*) void*))
  (define ffi-qt-scroll-area-set-widget
    (foreign-procedure "qt_scroll_area_set_widget" (void* void*) void))
  (define ffi-qt-scroll-area-set-widget-resizable
    (foreign-procedure "qt_scroll_area_set_widget_resizable" (void* int) void))
  (define ffi-qt-scroll-area-set-horizontal-scrollbar-policy
    (foreign-procedure "qt_scroll_area_set_horizontal_scrollbar_policy" (void* int) void))
  (define ffi-qt-scroll-area-set-vertical-scrollbar-policy
    (foreign-procedure "qt_scroll_area_set_vertical_scrollbar_policy" (void* int) void))

  ;; -----------------------------------------------------------------------
  ;; Splitter
  ;; -----------------------------------------------------------------------

  (define ffi-qt-splitter-create
    (foreign-procedure "qt_splitter_create" (int void*) void*))
  (define ffi-qt-splitter-add-widget
    (foreign-procedure "qt_splitter_add_widget" (void* void*) void))
  (define ffi-qt-splitter-insert-widget
    (foreign-procedure "qt_splitter_insert_widget" (void* int void*) void))
  (define ffi-qt-splitter-index-of
    (foreign-procedure "qt_splitter_index_of" (void* void*) int))
  (define ffi-qt-splitter-widget
    (foreign-procedure "qt_splitter_widget" (void* int) void*))
  (define ffi-qt-splitter-count
    (foreign-procedure "qt_splitter_count" (void*) int))
  (define ffi-qt-splitter-set-sizes-2
    (foreign-procedure "qt_splitter_set_sizes_2" (void* int int) void))
  (define ffi-qt-splitter-set-sizes-3
    (foreign-procedure "qt_splitter_set_sizes_3" (void* int int int) void))
  (define ffi-qt-splitter-set-sizes-4
    (foreign-procedure "qt_splitter_set_sizes_4" (void* int int int int) void))
  (define ffi-qt-splitter-size-at
    (foreign-procedure "qt_splitter_size_at" (void* int) int))
  (define ffi-qt-splitter-set-stretch-factor
    (foreign-procedure "qt_splitter_set_stretch_factor" (void* int int) void))
  (define ffi-qt-splitter-set-handle-width
    (foreign-procedure "qt_splitter_set_handle_width" (void* int) void))
  (define ffi-qt-splitter-set-collapsible
    (foreign-procedure "qt_splitter_set_collapsible" (void* int int) void))
  (define ffi-qt-splitter-is-collapsible
    (foreign-procedure "qt_splitter_is_collapsible" (void* int) int))
  (define ffi-qt-splitter-set-orientation
    (foreign-procedure "qt_splitter_set_orientation" (void* int) void))

  ;; -----------------------------------------------------------------------
  ;; Keyboard Events
  ;; -----------------------------------------------------------------------

  (define ffi-qt-install-key-handler
    (foreign-procedure "chez_qt_install_key_handler" (void* long) void))
  (define ffi-qt-install-key-handler-consuming
    (foreign-procedure "chez_qt_install_key_handler_consuming" (void* long) void))
  (define ffi-qt-last-key-code
    (foreign-procedure "qt_last_key_code" () int))
  (define ffi-qt-last-key-modifiers
    (foreign-procedure "qt_last_key_modifiers" () int))
  (define ffi-qt-last-key-text
    (foreign-procedure "qt_last_key_text" () string))
  (define ffi-qt-last-key-autorepeat
    (foreign-procedure "qt_last_key_autorepeat" () int))
  (define ffi-qt-last-key-widget
    (foreign-procedure "qt_last_key_widget" () void*))
  (define ffi-qt-send-key-event
    (foreign-procedure "qt_send_key_event" (void* int int int string) void))

  ;; -----------------------------------------------------------------------
  ;; Pixmap
  ;; -----------------------------------------------------------------------

  (define ffi-qt-pixmap-load
    (foreign-procedure "qt_pixmap_load" (string) void*))
  (define ffi-qt-pixmap-width
    (foreign-procedure "qt_pixmap_width" (void*) int))
  (define ffi-qt-pixmap-height
    (foreign-procedure "qt_pixmap_height" (void*) int))
  (define ffi-qt-pixmap-is-null
    (foreign-procedure "qt_pixmap_is_null" (void*) int))
  (define ffi-qt-pixmap-scaled
    (foreign-procedure "qt_pixmap_scaled" (void* int int int) void*))
  (define ffi-qt-pixmap-destroy
    (foreign-procedure "qt_pixmap_destroy" (void*) void))
  (define ffi-qt-pixmap-save
    (foreign-procedure "qt_pixmap_save" (void* string string) int))
  (define ffi-qt-widget-grab
    (foreign-procedure "qt_widget_grab" (void*) void*))

  ;; -----------------------------------------------------------------------
  ;; Icon
  ;; -----------------------------------------------------------------------

  (define ffi-qt-icon-create
    (foreign-procedure "qt_icon_create" (string) void*))
  (define ffi-qt-icon-create-from-pixmap
    (foreign-procedure "qt_icon_create_from_pixmap" (void*) void*))
  (define ffi-qt-icon-is-null
    (foreign-procedure "qt_icon_is_null" (void*) int))
  (define ffi-qt-icon-destroy
    (foreign-procedure "qt_icon_destroy" (void*) void))
  (define ffi-qt-widget-set-window-icon
    (foreign-procedure "qt_widget_set_window_icon" (void* void*) void))

  ;; -----------------------------------------------------------------------
  ;; Radio Button
  ;; -----------------------------------------------------------------------

  (define ffi-qt-radio-button-create
    (foreign-procedure "qt_radio_button_create" (string void*) void*))
  (define ffi-qt-radio-button-text
    (foreign-procedure "qt_radio_button_text" (void*) string))
  (define ffi-qt-radio-button-set-text
    (foreign-procedure "qt_radio_button_set_text" (void* string) void))
  (define ffi-qt-radio-button-is-checked
    (foreign-procedure "qt_radio_button_is_checked" (void*) int))
  (define ffi-qt-radio-button-set-checked
    (foreign-procedure "qt_radio_button_set_checked" (void* int) void))
  (define ffi-qt-radio-button-on-toggled
    (foreign-procedure "chez_qt_radio_button_on_toggled" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Button Group
  ;; -----------------------------------------------------------------------

  (define ffi-qt-button-group-create
    (foreign-procedure "qt_button_group_create" (void*) void*))
  (define ffi-qt-button-group-add-button
    (foreign-procedure "qt_button_group_add_button" (void* void* int) void))
  (define ffi-qt-button-group-remove-button
    (foreign-procedure "qt_button_group_remove_button" (void* void*) void))
  (define ffi-qt-button-group-checked-id
    (foreign-procedure "qt_button_group_checked_id" (void*) int))
  (define ffi-qt-button-group-set-exclusive
    (foreign-procedure "qt_button_group_set_exclusive" (void* int) void))
  (define ffi-qt-button-group-is-exclusive
    (foreign-procedure "qt_button_group_is_exclusive" (void*) int))
  (define ffi-qt-button-group-on-clicked
    (foreign-procedure "chez_qt_button_group_on_clicked" (void* long) void))
  (define ffi-qt-button-group-destroy
    (foreign-procedure "qt_button_group_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Group Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-group-box-create
    (foreign-procedure "qt_group_box_create" (string void*) void*))
  (define ffi-qt-group-box-title
    (foreign-procedure "qt_group_box_title" (void*) string))
  (define ffi-qt-group-box-set-title
    (foreign-procedure "qt_group_box_set_title" (void* string) void))
  (define ffi-qt-group-box-set-checkable
    (foreign-procedure "qt_group_box_set_checkable" (void* int) void))
  (define ffi-qt-group-box-is-checkable
    (foreign-procedure "qt_group_box_is_checkable" (void*) int))
  (define ffi-qt-group-box-set-checked
    (foreign-procedure "qt_group_box_set_checked" (void* int) void))
  (define ffi-qt-group-box-is-checked
    (foreign-procedure "qt_group_box_is_checked" (void*) int))
  (define ffi-qt-group-box-on-toggled
    (foreign-procedure "chez_qt_group_box_on_toggled" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Font
  ;; -----------------------------------------------------------------------

  (define ffi-qt-font-create
    (foreign-procedure "qt_font_create" (string int) void*))
  (define ffi-qt-font-family
    (foreign-procedure "qt_font_family" (void*) string))
  (define ffi-qt-font-point-size
    (foreign-procedure "qt_font_point_size" (void*) int))
  (define ffi-qt-font-is-bold
    (foreign-procedure "qt_font_is_bold" (void*) int))
  (define ffi-qt-font-set-bold
    (foreign-procedure "qt_font_set_bold" (void* int) void))
  (define ffi-qt-font-is-italic
    (foreign-procedure "qt_font_is_italic" (void*) int))
  (define ffi-qt-font-set-italic
    (foreign-procedure "qt_font_set_italic" (void* int) void))
  (define ffi-qt-font-destroy
    (foreign-procedure "qt_font_destroy" (void*) void))
  (define ffi-qt-widget-set-font
    (foreign-procedure "qt_widget_set_font" (void* void*) void))
  (define ffi-qt-widget-font
    (foreign-procedure "qt_widget_font" (void*) void*))

  ;; -----------------------------------------------------------------------
  ;; Color
  ;; -----------------------------------------------------------------------

  (define ffi-qt-color-create
    (foreign-procedure "qt_color_create_rgb" (int int int int) void*))
  (define ffi-qt-color-create-name
    (foreign-procedure "qt_color_create_name" (string) void*))
  (define ffi-qt-color-red
    (foreign-procedure "qt_color_red" (void*) int))
  (define ffi-qt-color-green
    (foreign-procedure "qt_color_green" (void*) int))
  (define ffi-qt-color-blue
    (foreign-procedure "qt_color_blue" (void*) int))
  (define ffi-qt-color-alpha
    (foreign-procedure "qt_color_alpha" (void*) int))
  (define ffi-qt-color-name
    (foreign-procedure "qt_color_name" (void*) string))
  (define ffi-qt-color-is-valid
    (foreign-procedure "qt_color_is_valid" (void*) int))
  (define ffi-qt-color-destroy
    (foreign-procedure "qt_color_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Font Dialog / Color Dialog
  ;; -----------------------------------------------------------------------

  (define ffi-qt-font-dialog-get-font
    (foreign-procedure "qt_font_dialog_get_font" (void*) void*))
  (define ffi-qt-color-dialog-get-color
    (foreign-procedure "qt_color_dialog_get_color" (string void*) void*))

  ;; -----------------------------------------------------------------------
  ;; Stacked Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-stacked-widget-create
    (foreign-procedure "qt_stacked_widget_create" (void*) void*))
  (define ffi-qt-stacked-widget-add-widget
    (foreign-procedure "qt_stacked_widget_add_widget" (void* void*) int))
  (define ffi-qt-stacked-widget-set-current-index
    (foreign-procedure "qt_stacked_widget_set_current_index" (void* int) void))
  (define ffi-qt-stacked-widget-current-index
    (foreign-procedure "qt_stacked_widget_current_index" (void*) int))
  (define ffi-qt-stacked-widget-count
    (foreign-procedure "qt_stacked_widget_count" (void*) int))
  (define ffi-qt-stacked-widget-on-current-changed
    (foreign-procedure "chez_qt_stacked_widget_on_current_changed" (void* long) void))
  (define ffi-qt-stacked-widget-set-current-widget
    (foreign-procedure "qt_stacked_widget_set_current_widget" (void* void*) void))

  ;; -----------------------------------------------------------------------
  ;; Dock Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-dock-widget-create
    (foreign-procedure "qt_dock_widget_create" (string void*) void*))
  (define ffi-qt-dock-widget-set-widget
    (foreign-procedure "qt_dock_widget_set_widget" (void* void*) void))
  (define ffi-qt-dock-widget-widget
    (foreign-procedure "qt_dock_widget_widget" (void*) void*))
  (define ffi-qt-dock-widget-set-title
    (foreign-procedure "qt_dock_widget_set_title" (void* string) void))
  (define ffi-qt-dock-widget-title
    (foreign-procedure "qt_dock_widget_title" (void*) string))
  (define ffi-qt-dock-widget-set-floating
    (foreign-procedure "qt_dock_widget_set_floating" (void* int) void))
  (define ffi-qt-dock-widget-is-floating
    (foreign-procedure "qt_dock_widget_is_floating" (void*) int))
  (define ffi-qt-main-window-add-dock-widget
    (foreign-procedure "qt_main_window_add_dock_widget" (void* int void*) void))

  ;; -----------------------------------------------------------------------
  ;; System Tray Icon
  ;; -----------------------------------------------------------------------

  (define ffi-qt-system-tray-icon-create
    (foreign-procedure "qt_system_tray_icon_create" (void* void*) void*))
  (define ffi-qt-system-tray-icon-set-tooltip
    (foreign-procedure "qt_system_tray_icon_set_tooltip" (void* string) void))
  (define ffi-qt-system-tray-icon-set-icon
    (foreign-procedure "qt_system_tray_icon_set_icon" (void* void*) void))
  (define ffi-qt-system-tray-icon-show
    (foreign-procedure "qt_system_tray_icon_show" (void*) void))
  (define ffi-qt-system-tray-icon-hide
    (foreign-procedure "qt_system_tray_icon_hide" (void*) void))
  (define ffi-qt-system-tray-icon-show-message
    (foreign-procedure "qt_system_tray_icon_show_message" (void* string string int int) void))
  (define ffi-qt-system-tray-icon-set-context-menu
    (foreign-procedure "qt_system_tray_icon_set_context_menu" (void* void*) void))
  (define ffi-qt-system-tray-icon-on-activated
    (foreign-procedure "chez_qt_system_tray_icon_on_activated" (void* long) void))
  (define ffi-qt-system-tray-icon-is-available
    (foreign-procedure "qt_system_tray_icon_is_available" () int))
  (define ffi-qt-system-tray-icon-destroy
    (foreign-procedure "qt_system_tray_icon_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; QPainter
  ;; -----------------------------------------------------------------------

  (define ffi-qt-pixmap-create-blank
    (foreign-procedure "qt_pixmap_create_blank" (int int) void*))
  (define ffi-qt-pixmap-fill
    (foreign-procedure "qt_pixmap_fill" (void* int int int int) void))
  (define ffi-qt-painter-create
    (foreign-procedure "qt_painter_create" (void*) void*))
  (define ffi-qt-painter-end
    (foreign-procedure "qt_painter_end" (void*) void))
  (define ffi-qt-painter-destroy
    (foreign-procedure "qt_painter_destroy" (void*) void))
  (define ffi-qt-painter-set-pen-color
    (foreign-procedure "qt_painter_set_pen_color" (void* int int int int) void))
  (define ffi-qt-painter-set-pen-width
    (foreign-procedure "qt_painter_set_pen_width" (void* int) void))
  (define ffi-qt-painter-set-brush-color
    (foreign-procedure "qt_painter_set_brush_color" (void* int int int int) void))
  (define ffi-qt-painter-set-font-painter
    (foreign-procedure "qt_painter_set_font" (void* void*) void))
  (define ffi-qt-painter-set-antialiasing
    (foreign-procedure "qt_painter_set_antialiasing" (void* int) void))
  (define ffi-qt-painter-draw-line
    (foreign-procedure "qt_painter_draw_line" (void* int int int int) void))
  (define ffi-qt-painter-draw-rect
    (foreign-procedure "qt_painter_draw_rect" (void* int int int int) void))
  (define ffi-qt-painter-fill-rect
    (foreign-procedure "qt_painter_fill_rect" (void* int int int int int int int int) void))
  (define ffi-qt-painter-draw-ellipse
    (foreign-procedure "qt_painter_draw_ellipse" (void* int int int int) void))
  (define ffi-qt-painter-draw-text
    (foreign-procedure "qt_painter_draw_text" (void* int int string) void))
  (define ffi-qt-painter-draw-text-rect
    (foreign-procedure "qt_painter_draw_text_rect" (void* int int int int int string) void))
  (define ffi-qt-painter-draw-pixmap
    (foreign-procedure "qt_painter_draw_pixmap" (void* int int void*) void))
  (define ffi-qt-painter-draw-point
    (foreign-procedure "qt_painter_draw_point" (void* int int) void))
  (define ffi-qt-painter-draw-arc
    (foreign-procedure "qt_painter_draw_arc" (void* int int int int int int) void))
  (define ffi-qt-painter-save
    (foreign-procedure "qt_painter_save" (void*) void))
  (define ffi-qt-painter-restore
    (foreign-procedure "qt_painter_restore" (void*) void))
  (define ffi-qt-painter-translate
    (foreign-procedure "qt_painter_translate" (void* int int) void))
  (define ffi-qt-painter-rotate
    (foreign-procedure "qt_painter_rotate" (void* double) void))
  (define ffi-qt-painter-scale
    (foreign-procedure "qt_painter_scale" (void* double double) void))

  ;; -----------------------------------------------------------------------
  ;; Drag and Drop
  ;; -----------------------------------------------------------------------

  (define ffi-qt-widget-set-accept-drops
    (foreign-procedure "qt_widget_set_accept_drops" (void* int) void))
  (define ffi-qt-drop-filter-install
    (foreign-procedure "qt_drop_filter_install" (void* void* long) void*))
  (define ffi-qt-drop-filter-last-text
    (foreign-procedure "qt_drop_filter_last_text" (void*) string))
  (define ffi-qt-drop-filter-destroy
    (foreign-procedure "qt_drop_filter_destroy" (void*) void))
  (define ffi-qt-drag-text
    (foreign-procedure "qt_drag_text" (void* string) void))

  ;; -----------------------------------------------------------------------
  ;; Double Spin Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-double-spin-box-create
    (foreign-procedure "qt_double_spin_box_create" (void*) void*))
  (define ffi-qt-double-spin-box-set-value
    (foreign-procedure "qt_double_spin_box_set_value" (void* double) void))
  (define ffi-qt-double-spin-box-value
    (foreign-procedure "qt_double_spin_box_value" (void*) double))
  (define ffi-qt-double-spin-box-set-range
    (foreign-procedure "qt_double_spin_box_set_range" (void* double double) void))
  (define ffi-qt-double-spin-box-set-single-step
    (foreign-procedure "qt_double_spin_box_set_single_step" (void* double) void))
  (define ffi-qt-double-spin-box-set-decimals
    (foreign-procedure "qt_double_spin_box_set_decimals" (void* int) void))
  (define ffi-qt-double-spin-box-decimals
    (foreign-procedure "qt_double_spin_box_decimals" (void*) int))
  (define ffi-qt-double-spin-box-set-prefix
    (foreign-procedure "qt_double_spin_box_set_prefix" (void* string) void))
  (define ffi-qt-double-spin-box-set-suffix
    (foreign-procedure "qt_double_spin_box_set_suffix" (void* string) void))
  (define ffi-qt-double-spin-box-on-value-changed
    (foreign-procedure "chez_qt_double_spin_box_on_value_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Date Edit
  ;; -----------------------------------------------------------------------

  (define ffi-qt-date-edit-create
    (foreign-procedure "qt_date_edit_create" (void*) void*))
  (define ffi-qt-date-edit-set-date
    (foreign-procedure "qt_date_edit_set_date" (void* int int int) void))
  (define ffi-qt-date-edit-year
    (foreign-procedure "qt_date_edit_year" (void*) int))
  (define ffi-qt-date-edit-month
    (foreign-procedure "qt_date_edit_month" (void*) int))
  (define ffi-qt-date-edit-day
    (foreign-procedure "qt_date_edit_day" (void*) int))
  (define ffi-qt-date-edit-date-string
    (foreign-procedure "qt_date_edit_date_string" (void*) string))
  (define ffi-qt-date-edit-set-minimum-date
    (foreign-procedure "qt_date_edit_set_minimum_date" (void* int int int) void))
  (define ffi-qt-date-edit-set-maximum-date
    (foreign-procedure "qt_date_edit_set_maximum_date" (void* int int int) void))
  (define ffi-qt-date-edit-set-calendar-popup
    (foreign-procedure "qt_date_edit_set_calendar_popup" (void* int) void))
  (define ffi-qt-date-edit-set-display-format
    (foreign-procedure "qt_date_edit_set_display_format" (void* string) void))
  (define ffi-qt-date-edit-on-date-changed
    (foreign-procedure "chez_qt_date_edit_on_date_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Time Edit
  ;; -----------------------------------------------------------------------

  (define ffi-qt-time-edit-create
    (foreign-procedure "qt_time_edit_create" (void*) void*))
  (define ffi-qt-time-edit-set-time
    (foreign-procedure "qt_time_edit_set_time" (void* int int int) void))
  (define ffi-qt-time-edit-hour
    (foreign-procedure "qt_time_edit_hour" (void*) int))
  (define ffi-qt-time-edit-minute
    (foreign-procedure "qt_time_edit_minute" (void*) int))
  (define ffi-qt-time-edit-second
    (foreign-procedure "qt_time_edit_second" (void*) int))
  (define ffi-qt-time-edit-time-string
    (foreign-procedure "qt_time_edit_time_string" (void*) string))
  (define ffi-qt-time-edit-set-display-format
    (foreign-procedure "qt_time_edit_set_display_format" (void* string) void))
  (define ffi-qt-time-edit-on-time-changed
    (foreign-procedure "chez_qt_time_edit_on_time_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Frame
  ;; -----------------------------------------------------------------------

  (define ffi-qt-frame-create
    (foreign-procedure "qt_frame_create" (void*) void*))
  (define ffi-qt-frame-set-frame-shape
    (foreign-procedure "qt_frame_set_frame_shape" (void* int) void))
  (define ffi-qt-frame-frame-shape
    (foreign-procedure "qt_frame_frame_shape" (void*) int))
  (define ffi-qt-frame-set-frame-shadow
    (foreign-procedure "qt_frame_set_frame_shadow" (void* int) void))
  (define ffi-qt-frame-frame-shadow
    (foreign-procedure "qt_frame_frame_shadow" (void*) int))
  (define ffi-qt-frame-set-line-width
    (foreign-procedure "qt_frame_set_line_width" (void* int) void))
  (define ffi-qt-frame-line-width
    (foreign-procedure "qt_frame_line_width" (void*) int))
  (define ffi-qt-frame-set-mid-line-width
    (foreign-procedure "qt_frame_set_mid_line_width" (void* int) void))

  ;; -----------------------------------------------------------------------
  ;; Progress Dialog
  ;; -----------------------------------------------------------------------

  (define ffi-qt-progress-dialog-create
    (foreign-procedure "qt_progress_dialog_create" (string string int int void*) void*))
  (define ffi-qt-progress-dialog-set-value
    (foreign-procedure "qt_progress_dialog_set_value" (void* int) void))
  (define ffi-qt-progress-dialog-value
    (foreign-procedure "qt_progress_dialog_value" (void*) int))
  (define ffi-qt-progress-dialog-set-range
    (foreign-procedure "qt_progress_dialog_set_range" (void* int int) void))
  (define ffi-qt-progress-dialog-set-label-text
    (foreign-procedure "qt_progress_dialog_set_label_text" (void* string) void))
  (define ffi-qt-progress-dialog-was-canceled
    (foreign-procedure "qt_progress_dialog_was_canceled" (void*) int))
  (define ffi-qt-progress-dialog-set-minimum-duration
    (foreign-procedure "qt_progress_dialog_set_minimum_duration" (void* int) void))
  (define ffi-qt-progress-dialog-set-auto-close
    (foreign-procedure "qt_progress_dialog_set_auto_close" (void* int) void))
  (define ffi-qt-progress-dialog-set-auto-reset
    (foreign-procedure "qt_progress_dialog_set_auto_reset" (void* int) void))
  (define ffi-qt-progress-dialog-reset
    (foreign-procedure "qt_progress_dialog_reset" (void*) void))
  (define ffi-qt-progress-dialog-on-canceled
    (foreign-procedure "chez_qt_progress_dialog_on_canceled" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Input Dialog
  ;; -----------------------------------------------------------------------

  (define ffi-qt-input-dialog-get-text
    (foreign-procedure "qt_input_dialog_get_text" (void* string string string) string))
  (define ffi-qt-input-dialog-get-int
    (foreign-procedure "qt_input_dialog_get_int" (void* string string int int int int) int))
  (define ffi-qt-input-dialog-get-double
    (foreign-procedure "qt_input_dialog_get_double" (void* string string double double double int) double))
  (define ffi-qt-input-dialog-get-item
    (foreign-procedure "qt_input_dialog_get_item" (void* string string string int int) string))
  (define ffi-qt-input-dialog-was-accepted
    (foreign-procedure "qt_input_dialog_was_accepted" () int))

  ;; -----------------------------------------------------------------------
  ;; Form Layout
  ;; -----------------------------------------------------------------------

  (define ffi-qt-form-layout-create
    (foreign-procedure "qt_form_layout_create" (void*) void*))
  (define ffi-qt-form-layout-add-row
    (foreign-procedure "qt_form_layout_add_row" (void* string void*) void))
  (define ffi-qt-form-layout-add-row-widget
    (foreign-procedure "qt_form_layout_add_row_widget" (void* void* void*) void))
  (define ffi-qt-form-layout-add-spanning-widget
    (foreign-procedure "qt_form_layout_add_spanning_widget" (void* void*) void))
  (define ffi-qt-form-layout-row-count
    (foreign-procedure "qt_form_layout_row_count" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; Shortcut
  ;; -----------------------------------------------------------------------

  (define ffi-qt-shortcut-create
    (foreign-procedure "qt_shortcut_create" (string void*) void*))
  (define ffi-qt-shortcut-set-key
    (foreign-procedure "qt_shortcut_set_key" (void* string) void))
  (define ffi-qt-shortcut-set-enabled
    (foreign-procedure "qt_shortcut_set_enabled" (void* int) void))
  (define ffi-qt-shortcut-is-enabled
    (foreign-procedure "qt_shortcut_is_enabled" (void*) int))
  (define ffi-qt-shortcut-on-activated
    (foreign-procedure "chez_qt_shortcut_on_activated" (void* long) void))
  (define ffi-qt-shortcut-destroy
    (foreign-procedure "qt_shortcut_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Text Browser
  ;; -----------------------------------------------------------------------

  (define ffi-qt-text-browser-create
    (foreign-procedure "qt_text_browser_create" (void*) void*))
  (define ffi-qt-text-browser-set-html
    (foreign-procedure "qt_text_browser_set_html" (void* string) void))
  (define ffi-qt-text-browser-set-plain-text
    (foreign-procedure "qt_text_browser_set_plain_text" (void* string) void))
  (define ffi-qt-text-browser-plain-text
    (foreign-procedure "qt_text_browser_plain_text" (void*) string))
  (define ffi-qt-text-browser-set-open-external-links
    (foreign-procedure "qt_text_browser_set_open_external_links" (void* int) void))
  (define ffi-qt-text-browser-set-source
    (foreign-procedure "qt_text_browser_set_source" (void* string) void))
  (define ffi-qt-text-browser-source
    (foreign-procedure "qt_text_browser_source" (void*) string))
  (define ffi-qt-text-browser-scroll-to-bottom
    (foreign-procedure "qt_text_browser_scroll_to_bottom" (void*) void))
  (define ffi-qt-text-browser-append
    (foreign-procedure "qt_text_browser_append" (void* string) void))
  (define ffi-qt-text-browser-html
    (foreign-procedure "qt_text_browser_html" (void*) string))
  (define ffi-qt-text-browser-on-anchor-clicked
    (foreign-procedure "chez_qt_text_browser_on_anchor_clicked" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Button Box
  ;; -----------------------------------------------------------------------

  (define ffi-qt-button-box-create
    (foreign-procedure "qt_button_box_create" (int void*) void*))
  (define ffi-qt-button-box-button
    (foreign-procedure "qt_button_box_button" (void* int) void*))
  (define ffi-qt-button-box-add-button
    (foreign-procedure "qt_button_box_add_button" (void* void* int) void))
  (define ffi-qt-button-box-on-accepted
    (foreign-procedure "chez_qt_button_box_on_accepted" (void* long) void))
  (define ffi-qt-button-box-on-rejected
    (foreign-procedure "chez_qt_button_box_on_rejected" (void* long) void))
  (define ffi-qt-button-box-on-clicked
    (foreign-procedure "chez_qt_button_box_on_clicked" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Calendar
  ;; -----------------------------------------------------------------------

  (define ffi-qt-calendar-create
    (foreign-procedure "qt_calendar_create" (void*) void*))
  (define ffi-qt-calendar-set-selected-date
    (foreign-procedure "qt_calendar_set_selected_date" (void* int int int) void))
  (define ffi-qt-calendar-selected-year
    (foreign-procedure "qt_calendar_selected_year" (void*) int))
  (define ffi-qt-calendar-selected-month
    (foreign-procedure "qt_calendar_selected_month" (void*) int))
  (define ffi-qt-calendar-selected-day
    (foreign-procedure "qt_calendar_selected_day" (void*) int))
  (define ffi-qt-calendar-selected-date-string
    (foreign-procedure "qt_calendar_selected_date_string" (void*) string))
  (define ffi-qt-calendar-set-minimum-date
    (foreign-procedure "qt_calendar_set_minimum_date" (void* int int int) void))
  (define ffi-qt-calendar-set-maximum-date
    (foreign-procedure "qt_calendar_set_maximum_date" (void* int int int) void))
  (define ffi-qt-calendar-set-first-day-of-week
    (foreign-procedure "qt_calendar_set_first_day_of_week" (void* int) void))
  (define ffi-qt-calendar-set-grid-visible
    (foreign-procedure "qt_calendar_set_grid_visible" (void* int) void))
  (define ffi-qt-calendar-is-grid-visible
    (foreign-procedure "qt_calendar_is_grid_visible" (void*) int))
  (define ffi-qt-calendar-set-navigation-bar-visible
    (foreign-procedure "qt_calendar_set_navigation_bar_visible" (void* int) void))
  (define ffi-qt-calendar-on-selection-changed
    (foreign-procedure "chez_qt_calendar_on_selection_changed" (void* long) void))
  (define ffi-qt-calendar-on-clicked
    (foreign-procedure "chez_qt_calendar_on_clicked" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; QSettings
  ;; -----------------------------------------------------------------------

  (define ffi-qt-settings-create
    (foreign-procedure "qt_settings_create" (string string) void*))
  (define ffi-qt-settings-create-file
    (foreign-procedure "qt_settings_create_file" (string int) void*))
  (define ffi-qt-settings-set-string
    (foreign-procedure "qt_settings_set_string" (void* string string) void))
  (define ffi-qt-settings-value-string
    (foreign-procedure "qt_settings_value_string" (void* string string) string))
  (define ffi-qt-settings-set-int
    (foreign-procedure "qt_settings_set_int" (void* string int) void))
  (define ffi-qt-settings-value-int
    (foreign-procedure "qt_settings_value_int" (void* string int) int))
  (define ffi-qt-settings-set-double
    (foreign-procedure "qt_settings_set_double" (void* string double) void))
  (define ffi-qt-settings-value-double
    (foreign-procedure "qt_settings_value_double" (void* string double) double))
  (define ffi-qt-settings-set-bool
    (foreign-procedure "qt_settings_set_bool" (void* string int) void))
  (define ffi-qt-settings-value-bool
    (foreign-procedure "qt_settings_value_bool" (void* string int) int))
  (define ffi-qt-settings-contains
    (foreign-procedure "qt_settings_contains" (void* string) int))
  (define ffi-qt-settings-remove
    (foreign-procedure "qt_settings_remove" (void* string) void))
  (define ffi-qt-settings-all-keys
    (foreign-procedure "qt_settings_all_keys" (void*) string))
  (define ffi-qt-settings-child-keys
    (foreign-procedure "qt_settings_child_keys" (void*) string))
  (define ffi-qt-settings-child-groups
    (foreign-procedure "qt_settings_child_groups" (void*) string))
  (define ffi-qt-settings-begin-group
    (foreign-procedure "qt_settings_begin_group" (void* string) void))
  (define ffi-qt-settings-end-group
    (foreign-procedure "qt_settings_end_group" (void*) void))
  (define ffi-qt-settings-group
    (foreign-procedure "qt_settings_group" (void*) string))
  (define ffi-qt-settings-sync
    (foreign-procedure "qt_settings_sync" (void*) void))
  (define ffi-qt-settings-clear
    (foreign-procedure "qt_settings_clear" (void*) void))
  (define ffi-qt-settings-file-name
    (foreign-procedure "qt_settings_file_name" (void*) string))
  (define ffi-qt-settings-is-writable
    (foreign-procedure "qt_settings_is_writable" (void*) int))
  (define ffi-qt-settings-destroy
    (foreign-procedure "qt_settings_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; QCompleter
  ;; -----------------------------------------------------------------------

  (define ffi-qt-completer-create
    (foreign-procedure "qt_completer_create" (string) void*))
  (define ffi-qt-completer-set-model-strings
    (foreign-procedure "qt_completer_set_model_strings" (void* string) void))
  (define ffi-qt-completer-set-case-sensitivity
    (foreign-procedure "qt_completer_set_case_sensitivity" (void* int) void))
  (define ffi-qt-completer-set-completion-mode
    (foreign-procedure "qt_completer_set_completion_mode" (void* int) void))
  (define ffi-qt-completer-set-filter-mode
    (foreign-procedure "qt_completer_set_filter_mode" (void* int) void))
  (define ffi-qt-completer-set-max-visible-items
    (foreign-procedure "qt_completer_set_max_visible_items" (void* int) void))
  (define ffi-qt-completer-completion-count
    (foreign-procedure "qt_completer_completion_count" (void*) int))
  (define ffi-qt-completer-current-completion
    (foreign-procedure "qt_completer_current_completion" (void*) string))
  (define ffi-qt-completer-set-completion-prefix
    (foreign-procedure "qt_completer_set_completion_prefix" (void* string) void))
  (define ffi-qt-completer-on-activated
    (foreign-procedure "chez_qt_completer_on_activated" (void* long) void))
  (define ffi-qt-line-edit-set-completer
    (foreign-procedure "qt_line_edit_set_completer" (void* void*) void))
  (define ffi-qt-completer-destroy
    (foreign-procedure "qt_completer_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Tooltip / WhatsThis
  ;; -----------------------------------------------------------------------

  (define ffi-qt-tooltip-show-text
    (foreign-procedure "qt_tooltip_show_text" (int int string void*) void))
  (define ffi-qt-tooltip-hide-text
    (foreign-procedure "qt_tooltip_hide_text" () void))
  (define ffi-qt-tooltip-is-visible
    (foreign-procedure "qt_tooltip_is_visible" () int))
  (define ffi-qt-widget-tooltip
    (foreign-procedure "qt_widget_tooltip" (void*) string))
  (define ffi-qt-widget-set-whats-this
    (foreign-procedure "qt_widget_set_whats_this" (void* string) void))
  (define ffi-qt-widget-whats-this
    (foreign-procedure "qt_widget_whats_this" (void*) string))

  ;; -----------------------------------------------------------------------
  ;; QStandardItemModel
  ;; -----------------------------------------------------------------------

  (define ffi-qt-standard-model-create
    (foreign-procedure "qt_standard_model_create" (int int void*) void*))
  (define ffi-qt-standard-model-destroy
    (foreign-procedure "qt_standard_model_destroy" (void*) void))
  (define ffi-qt-standard-model-row-count
    (foreign-procedure "qt_standard_model_row_count" (void*) int))
  (define ffi-qt-standard-model-column-count
    (foreign-procedure "qt_standard_model_column_count" (void*) int))
  (define ffi-qt-standard-model-set-row-count
    (foreign-procedure "qt_standard_model_set_row_count" (void* int) void))
  (define ffi-qt-standard-model-set-column-count
    (foreign-procedure "qt_standard_model_set_column_count" (void* int) void))
  (define ffi-qt-standard-model-set-item
    (foreign-procedure "qt_standard_model_set_item" (void* int int void*) void))
  (define ffi-qt-standard-model-item
    (foreign-procedure "qt_standard_model_item" (void* int int) void*))
  (define ffi-qt-standard-model-insert-row
    (foreign-procedure "qt_standard_model_insert_row" (void* int) int))
  (define ffi-qt-standard-model-insert-column
    (foreign-procedure "qt_standard_model_insert_column" (void* int) int))
  (define ffi-qt-standard-model-remove-row
    (foreign-procedure "qt_standard_model_remove_row" (void* int) int))
  (define ffi-qt-standard-model-remove-column
    (foreign-procedure "qt_standard_model_remove_column" (void* int) int))
  (define ffi-qt-standard-model-clear
    (foreign-procedure "qt_standard_model_clear" (void*) void))
  (define ffi-qt-standard-model-set-horizontal-header
    (foreign-procedure "qt_standard_model_set_horizontal_header" (void* int string) void))
  (define ffi-qt-standard-model-set-vertical-header
    (foreign-procedure "qt_standard_model_set_vertical_header" (void* int string) void))

  ;; -----------------------------------------------------------------------
  ;; QStandardItem
  ;; -----------------------------------------------------------------------

  (define ffi-qt-standard-item-create
    (foreign-procedure "qt_standard_item_create" (string) void*))
  (define ffi-qt-standard-item-text
    (foreign-procedure "qt_standard_item_text" (void*) string))
  (define ffi-qt-standard-item-set-text
    (foreign-procedure "qt_standard_item_set_text" (void* string) void))
  (define ffi-qt-standard-item-tooltip
    (foreign-procedure "qt_standard_item_tooltip" (void*) string))
  (define ffi-qt-standard-item-set-tooltip
    (foreign-procedure "qt_standard_item_set_tooltip" (void* string) void))
  (define ffi-qt-standard-item-set-editable
    (foreign-procedure "qt_standard_item_set_editable" (void* int) void))
  (define ffi-qt-standard-item-is-editable
    (foreign-procedure "qt_standard_item_is_editable" (void*) int))
  (define ffi-qt-standard-item-set-enabled
    (foreign-procedure "qt_standard_item_set_enabled" (void* int) void))
  (define ffi-qt-standard-item-is-enabled
    (foreign-procedure "qt_standard_item_is_enabled" (void*) int))
  (define ffi-qt-standard-item-set-selectable
    (foreign-procedure "qt_standard_item_set_selectable" (void* int) void))
  (define ffi-qt-standard-item-is-selectable
    (foreign-procedure "qt_standard_item_is_selectable" (void*) int))
  (define ffi-qt-standard-item-set-checkable
    (foreign-procedure "qt_standard_item_set_checkable" (void* int) void))
  (define ffi-qt-standard-item-is-checkable
    (foreign-procedure "qt_standard_item_is_checkable" (void*) int))
  (define ffi-qt-standard-item-set-check-state
    (foreign-procedure "qt_standard_item_set_check_state" (void* int) void))
  (define ffi-qt-standard-item-check-state
    (foreign-procedure "qt_standard_item_check_state" (void*) int))
  (define ffi-qt-standard-item-set-icon
    (foreign-procedure "qt_standard_item_set_icon" (void* void*) void))
  (define ffi-qt-standard-item-append-row
    (foreign-procedure "qt_standard_item_append_row" (void* void*) void))
  (define ffi-qt-standard-item-row-count
    (foreign-procedure "qt_standard_item_row_count" (void*) int))
  (define ffi-qt-standard-item-column-count
    (foreign-procedure "qt_standard_item_column_count" (void*) int))
  (define ffi-qt-standard-item-child
    (foreign-procedure "qt_standard_item_child" (void* int int) void*))

  ;; -----------------------------------------------------------------------
  ;; QStringListModel
  ;; -----------------------------------------------------------------------

  (define ffi-qt-string-list-model-create
    (foreign-procedure "qt_string_list_model_create" (string) void*))
  (define ffi-qt-string-list-model-destroy
    (foreign-procedure "qt_string_list_model_destroy" (void*) void))
  (define ffi-qt-string-list-model-set-strings
    (foreign-procedure "qt_string_list_model_set_strings" (void* string) void))
  (define ffi-qt-string-list-model-strings
    (foreign-procedure "qt_string_list_model_strings" (void*) string))
  (define ffi-qt-string-list-model-row-count
    (foreign-procedure "qt_string_list_model_row_count" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; Views (common)
  ;; -----------------------------------------------------------------------

  (define ffi-qt-view-set-model
    (foreign-procedure "qt_view_set_model" (void* void*) void))
  (define ffi-qt-view-set-selection-mode
    (foreign-procedure "qt_view_set_selection_mode" (void* int) void))
  (define ffi-qt-view-set-selection-behavior
    (foreign-procedure "qt_view_set_selection_behavior" (void* int) void))
  (define ffi-qt-view-set-alternating-row-colors
    (foreign-procedure "qt_view_set_alternating_row_colors" (void* int) void))
  (define ffi-qt-view-set-sorting-enabled
    (foreign-procedure "qt_view_set_sorting_enabled" (void* int) void))
  (define ffi-qt-view-set-edit-triggers
    (foreign-procedure "qt_view_set_edit_triggers" (void* int) void))

  ;; QListView
  (define ffi-qt-list-view-create
    (foreign-procedure "qt_list_view_create" (void*) void*))
  (define ffi-qt-list-view-set-flow
    (foreign-procedure "qt_list_view_set_flow" (void* int) void))

  ;; QTableView
  (define ffi-qt-table-view-create
    (foreign-procedure "qt_table_view_create" (void*) void*))
  (define ffi-qt-table-view-set-column-width
    (foreign-procedure "qt_table_view_set_column_width" (void* int int) void))
  (define ffi-qt-table-view-set-row-height
    (foreign-procedure "qt_table_view_set_row_height" (void* int int) void))
  (define ffi-qt-table-view-hide-column
    (foreign-procedure "qt_table_view_hide_column" (void* int) void))
  (define ffi-qt-table-view-show-column
    (foreign-procedure "qt_table_view_show_column" (void* int) void))
  (define ffi-qt-table-view-hide-row
    (foreign-procedure "qt_table_view_hide_row" (void* int) void))
  (define ffi-qt-table-view-show-row
    (foreign-procedure "qt_table_view_show_row" (void* int) void))
  (define ffi-qt-table-view-resize-columns-to-contents
    (foreign-procedure "qt_table_view_resize_columns_to_contents" (void*) void))
  (define ffi-qt-table-view-resize-rows-to-contents
    (foreign-procedure "qt_table_view_resize_rows_to_contents" (void*) void))

  ;; QTreeView
  (define ffi-qt-tree-view-create
    (foreign-procedure "qt_tree_view_create" (void*) void*))
  (define ffi-qt-tree-view-expand-all
    (foreign-procedure "qt_tree_view_expand_all" (void*) void))
  (define ffi-qt-tree-view-collapse-all
    (foreign-procedure "qt_tree_view_collapse_all" (void*) void))
  (define ffi-qt-tree-view-set-indentation
    (foreign-procedure "qt_tree_view_set_indentation" (void* int) void))
  (define ffi-qt-tree-view-indentation
    (foreign-procedure "qt_tree_view_indentation" (void*) int))
  (define ffi-qt-tree-view-set-root-is-decorated
    (foreign-procedure "qt_tree_view_set_root_is_decorated" (void* int) void))
  (define ffi-qt-tree-view-set-header-hidden
    (foreign-procedure "qt_tree_view_set_header_hidden" (void* int) void))
  (define ffi-qt-tree-view-set-column-width
    (foreign-procedure "qt_tree_view_set_column_width" (void* int int) void))

  ;; QHeaderView (via view)
  (define ffi-qt-view-header-set-stretch-last-section
    (foreign-procedure "qt_view_header_set_stretch_last_section" (void* int int) void))
  (define ffi-qt-view-header-set-section-resize-mode
    (foreign-procedure "qt_view_header_set_section_resize_mode" (void* int int) void))
  (define ffi-qt-view-header-hide
    (foreign-procedure "qt_view_header_hide" (void* int) void))
  (define ffi-qt-view-header-show
    (foreign-procedure "qt_view_header_show" (void* int) void))
  (define ffi-qt-view-header-set-default-section-size
    (foreign-procedure "qt_view_header_set_default_section_size" (void* int int) void))

  ;; -----------------------------------------------------------------------
  ;; QSortFilterProxyModel
  ;; -----------------------------------------------------------------------

  (define ffi-qt-sort-filter-proxy-create
    (foreign-procedure "qt_sort_filter_proxy_create" (void*) void*))
  (define ffi-qt-sort-filter-proxy-destroy
    (foreign-procedure "qt_sort_filter_proxy_destroy" (void*) void))
  (define ffi-qt-sort-filter-proxy-set-source-model
    (foreign-procedure "qt_sort_filter_proxy_set_source_model" (void* void*) void))
  (define ffi-qt-sort-filter-proxy-set-filter-regex
    (foreign-procedure "qt_sort_filter_proxy_set_filter_regex" (void* string) void))
  (define ffi-qt-sort-filter-proxy-set-filter-column
    (foreign-procedure "qt_sort_filter_proxy_set_filter_column" (void* int) void))
  (define ffi-qt-sort-filter-proxy-set-filter-case-sensitivity
    (foreign-procedure "qt_sort_filter_proxy_set_filter_case_sensitivity" (void* int) void))
  (define ffi-qt-sort-filter-proxy-set-filter-role
    (foreign-procedure "qt_sort_filter_proxy_set_filter_role" (void* int) void))
  (define ffi-qt-sort-filter-proxy-sort
    (foreign-procedure "qt_sort_filter_proxy_sort" (void* int int) void))
  (define ffi-qt-sort-filter-proxy-set-sort-role
    (foreign-procedure "qt_sort_filter_proxy_set_sort_role" (void* int) void))
  (define ffi-qt-sort-filter-proxy-set-dynamic-sort-filter
    (foreign-procedure "qt_sort_filter_proxy_set_dynamic_sort_filter" (void* int) void))
  (define ffi-qt-sort-filter-proxy-invalidate-filter
    (foreign-procedure "qt_sort_filter_proxy_invalidate_filter" (void*) void))
  (define ffi-qt-sort-filter-proxy-row-count
    (foreign-procedure "qt_sort_filter_proxy_row_count" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; View signals + selection
  ;; -----------------------------------------------------------------------

  (define ffi-qt-view-on-clicked
    (foreign-procedure "chez_qt_view_on_clicked" (void* long) void))
  (define ffi-qt-view-on-double-clicked
    (foreign-procedure "chez_qt_view_on_double_clicked" (void* long) void))
  (define ffi-qt-view-on-activated
    (foreign-procedure "chez_qt_view_on_activated" (void* long) void))
  (define ffi-qt-view-on-selection-changed
    (foreign-procedure "chez_qt_view_on_selection_changed" (void* long) void))
  (define ffi-qt-view-last-clicked-row
    (foreign-procedure "qt_view_last_clicked_row" () int))
  (define ffi-qt-view-last-clicked-col
    (foreign-procedure "qt_view_last_clicked_col" () int))
  (define ffi-qt-view-selected-rows
    (foreign-procedure "qt_view_selected_rows" (void*) string))
  (define ffi-qt-view-current-row
    (foreign-procedure "qt_view_current_row" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; Validators
  ;; -----------------------------------------------------------------------

  (define ffi-qt-int-validator-create
    (foreign-procedure "qt_int_validator_create" (int int void*) void*))
  (define ffi-qt-double-validator-create
    (foreign-procedure "qt_double_validator_create" (double double int void*) void*))
  (define ffi-qt-regex-validator-create
    (foreign-procedure "qt_regex_validator_create" (string void*) void*))
  (define ffi-qt-validator-destroy
    (foreign-procedure "qt_validator_destroy" (void*) void))
  (define ffi-qt-validator-validate
    (foreign-procedure "qt_validator_validate" (void* string) int))
  (define ffi-qt-line-edit-set-validator
    (foreign-procedure "qt_line_edit_set_validator" (void* void*) void))
  (define ffi-qt-line-edit-has-acceptable-input
    (foreign-procedure "qt_line_edit_has_acceptable_input" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; QPlainTextEdit
  ;; -----------------------------------------------------------------------

  (define ffi-qt-plain-text-edit-create
    (foreign-procedure "qt_plain_text_edit_create" (void*) void*))
  (define ffi-qt-plain-text-edit-set-text
    (foreign-procedure "qt_plain_text_edit_set_text" (void* string) void))
  (define ffi-qt-plain-text-edit-text
    (foreign-procedure "qt_plain_text_edit_text" (void*) string))
  (define ffi-qt-plain-text-edit-append
    (foreign-procedure "qt_plain_text_edit_append" (void* string) void))
  (define ffi-qt-plain-text-edit-clear
    (foreign-procedure "qt_plain_text_edit_clear" (void*) void))
  (define ffi-qt-plain-text-edit-set-read-only
    (foreign-procedure "qt_plain_text_edit_set_read_only" (void* int) void))
  (define ffi-qt-plain-text-edit-is-read-only
    (foreign-procedure "qt_plain_text_edit_is_read_only" (void*) int))
  (define ffi-qt-plain-text-edit-set-placeholder
    (foreign-procedure "qt_plain_text_edit_set_placeholder" (void* string) void))
  (define ffi-qt-plain-text-edit-line-count
    (foreign-procedure "qt_plain_text_edit_line_count" (void*) int))
  (define ffi-qt-plain-text-edit-set-max-block-count
    (foreign-procedure "qt_plain_text_edit_set_max_block_count" (void* int) void))
  (define ffi-qt-plain-text-edit-cursor-line
    (foreign-procedure "qt_plain_text_edit_cursor_line" (void*) int))
  (define ffi-qt-plain-text-edit-cursor-column
    (foreign-procedure "qt_plain_text_edit_cursor_column" (void*) int))
  (define ffi-qt-plain-text-edit-set-line-wrap
    (foreign-procedure "qt_plain_text_edit_set_line_wrap" (void* int) void))
  (define ffi-qt-plain-text-edit-on-text-changed
    (foreign-procedure "chez_qt_plain_text_edit_on_text_changed" (void* long) void))

  ;; Editor extensions
  (define ffi-qt-plain-text-edit-cursor-position
    (foreign-procedure "qt_plain_text_edit_cursor_position" (void*) int))
  (define ffi-qt-plain-text-edit-set-cursor-position
    (foreign-procedure "qt_plain_text_edit_set_cursor_position" (void* int) void))
  (define ffi-qt-plain-text-edit-move-cursor
    (foreign-procedure "qt_plain_text_edit_move_cursor" (void* int int) void))
  (define ffi-qt-plain-text-edit-select-all
    (foreign-procedure "qt_plain_text_edit_select_all" (void*) void))
  (define ffi-qt-plain-text-edit-selected-text
    (foreign-procedure "qt_plain_text_edit_selected_text" (void*) string))
  (define ffi-qt-plain-text-edit-selection-start
    (foreign-procedure "qt_plain_text_edit_selection_start" (void*) int))
  (define ffi-qt-plain-text-edit-selection-end
    (foreign-procedure "qt_plain_text_edit_selection_end" (void*) int))
  (define ffi-qt-plain-text-edit-set-selection
    (foreign-procedure "qt_plain_text_edit_set_selection" (void* int int) void))
  (define ffi-qt-plain-text-edit-has-selection
    (foreign-procedure "qt_plain_text_edit_has_selection" (void*) int))
  (define ffi-qt-plain-text-edit-insert-text
    (foreign-procedure "qt_plain_text_edit_insert_text" (void* string) void))
  (define ffi-qt-plain-text-edit-remove-selected-text
    (foreign-procedure "qt_plain_text_edit_remove_selected_text" (void*) void))
  (define ffi-qt-plain-text-edit-undo
    (foreign-procedure "qt_plain_text_edit_undo" (void*) void))
  (define ffi-qt-plain-text-edit-redo
    (foreign-procedure "qt_plain_text_edit_redo" (void*) void))
  (define ffi-qt-plain-text-edit-can-undo
    (foreign-procedure "qt_plain_text_edit_can_undo" (void*) int))
  (define ffi-qt-plain-text-edit-cut
    (foreign-procedure "qt_plain_text_edit_cut" (void*) void))
  (define ffi-qt-plain-text-edit-copy
    (foreign-procedure "qt_plain_text_edit_copy" (void*) void))
  (define ffi-qt-plain-text-edit-paste
    (foreign-procedure "qt_plain_text_edit_paste" (void*) void))
  (define ffi-qt-plain-text-edit-text-length
    (foreign-procedure "qt_plain_text_edit_text_length" (void*) int))
  (define ffi-qt-plain-text-edit-text-range
    (foreign-procedure "qt_plain_text_edit_text_range" (void* int int) string))
  (define ffi-qt-plain-text-edit-line-from-position
    (foreign-procedure "qt_plain_text_edit_line_from_position" (void* int) int))
  (define ffi-qt-plain-text-edit-line-end-position
    (foreign-procedure "qt_plain_text_edit_line_end_position" (void* int) int))
  (define ffi-qt-plain-text-edit-find-text
    (foreign-procedure "qt_plain_text_edit_find_text" (void* string int) int))
  (define ffi-qt-plain-text-edit-ensure-cursor-visible
    (foreign-procedure "qt_plain_text_edit_ensure_cursor_visible" (void*) void))
  (define ffi-qt-plain-text-edit-center-cursor
    (foreign-procedure "qt_plain_text_edit_center_cursor" (void*) void))
  (define ffi-qt-text-document-create
    (foreign-procedure "qt_text_document_create" () void*))
  (define ffi-qt-plain-text-document-create
    (foreign-procedure "qt_plain_text_document_create" () void*))
  (define ffi-qt-text-document-destroy
    (foreign-procedure "qt_text_document_destroy" (void*) void))
  (define ffi-qt-plain-text-edit-document
    (foreign-procedure "qt_plain_text_edit_document" (void*) void*))
  (define ffi-qt-plain-text-edit-set-document
    (foreign-procedure "qt_plain_text_edit_set_document" (void* void*) void))
  (define ffi-qt-text-document-is-modified
    (foreign-procedure "qt_text_document_is_modified" (void*) int))
  (define ffi-qt-text-document-set-modified
    (foreign-procedure "qt_text_document_set_modified" (void* int) void))

  ;; -----------------------------------------------------------------------
  ;; QToolButton
  ;; -----------------------------------------------------------------------

  (define ffi-qt-tool-button-create
    (foreign-procedure "qt_tool_button_create" (void*) void*))
  (define ffi-qt-tool-button-set-text
    (foreign-procedure "qt_tool_button_set_text" (void* string) void))
  (define ffi-qt-tool-button-text
    (foreign-procedure "qt_tool_button_text" (void*) string))
  (define ffi-qt-tool-button-set-icon
    (foreign-procedure "qt_tool_button_set_icon" (void* string) void))
  (define ffi-qt-tool-button-set-menu
    (foreign-procedure "qt_tool_button_set_menu" (void* void*) void))
  (define ffi-qt-tool-button-set-popup-mode
    (foreign-procedure "qt_tool_button_set_popup_mode" (void* int) void))
  (define ffi-qt-tool-button-set-auto-raise
    (foreign-procedure "qt_tool_button_set_auto_raise" (void* int) void))
  (define ffi-qt-tool-button-set-arrow-type
    (foreign-procedure "qt_tool_button_set_arrow_type" (void* int) void))
  (define ffi-qt-tool-button-set-tool-button-style
    (foreign-procedure "qt_tool_button_set_tool_button_style" (void* int) void))
  (define ffi-qt-tool-button-on-clicked
    (foreign-procedure "chez_qt_tool_button_on_clicked" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; Layout spacers / Size policy
  ;; -----------------------------------------------------------------------

  (define ffi-qt-layout-add-spacing
    (foreign-procedure "qt_layout_add_spacing" (void* int) void))
  (define ffi-qt-widget-set-size-policy
    (foreign-procedure "qt_widget_set_size_policy" (void* int int) void))
  (define ffi-qt-layout-set-stretch-factor
    (foreign-procedure "qt_layout_set_stretch_factor" (void* void* int) void))

  ;; -----------------------------------------------------------------------
  ;; Graphics Scene
  ;; -----------------------------------------------------------------------

  (define ffi-qt-graphics-scene-create
    (foreign-procedure "qt_graphics_scene_create" (double double double double) void*))
  (define ffi-qt-graphics-scene-add-rect
    (foreign-procedure "qt_graphics_scene_add_rect" (void* double double double double) void*))
  (define ffi-qt-graphics-scene-add-ellipse
    (foreign-procedure "qt_graphics_scene_add_ellipse" (void* double double double double) void*))
  (define ffi-qt-graphics-scene-add-line
    (foreign-procedure "qt_graphics_scene_add_line" (void* double double double double) void*))
  (define ffi-qt-graphics-scene-add-text
    (foreign-procedure "qt_graphics_scene_add_text" (void* string) void*))
  (define ffi-qt-graphics-scene-add-pixmap
    (foreign-procedure "qt_graphics_scene_add_pixmap" (void* void*) void*))
  (define ffi-qt-graphics-scene-remove-item
    (foreign-procedure "qt_graphics_scene_remove_item" (void* void*) void))
  (define ffi-qt-graphics-scene-clear
    (foreign-procedure "qt_graphics_scene_clear" (void*) void))
  (define ffi-qt-graphics-scene-items-count
    (foreign-procedure "qt_graphics_scene_items_count" (void*) int))
  (define ffi-qt-graphics-scene-set-background
    (foreign-procedure "qt_graphics_scene_set_background" (void* int int int) void))
  (define ffi-qt-graphics-scene-destroy
    (foreign-procedure "qt_graphics_scene_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Graphics View
  ;; -----------------------------------------------------------------------

  (define ffi-qt-graphics-view-create
    (foreign-procedure "qt_graphics_view_create" (void* void*) void*))
  (define ffi-qt-graphics-view-set-render-hint
    (foreign-procedure "qt_graphics_view_set_render_hint" (void* int int) void))
  (define ffi-qt-graphics-view-set-drag-mode
    (foreign-procedure "qt_graphics_view_set_drag_mode" (void* int) void))
  (define ffi-qt-graphics-view-fit-in-view
    (foreign-procedure "qt_graphics_view_fit_in_view" (void*) void))
  (define ffi-qt-graphics-view-scale
    (foreign-procedure "qt_graphics_view_scale" (void* double double) void))
  (define ffi-qt-graphics-view-center-on
    (foreign-procedure "qt_graphics_view_center_on" (void* double double) void))

  ;; -----------------------------------------------------------------------
  ;; Graphics Item
  ;; -----------------------------------------------------------------------

  (define ffi-qt-graphics-item-set-pos
    (foreign-procedure "qt_graphics_item_set_pos" (void* double double) void))
  (define ffi-qt-graphics-item-x
    (foreign-procedure "qt_graphics_item_x" (void*) double))
  (define ffi-qt-graphics-item-y
    (foreign-procedure "qt_graphics_item_y" (void*) double))
  (define ffi-qt-graphics-item-set-pen
    (foreign-procedure "qt_graphics_item_set_pen" (void* int int int int) void))
  (define ffi-qt-graphics-item-set-brush
    (foreign-procedure "qt_graphics_item_set_brush" (void* int int int) void))
  (define ffi-qt-graphics-item-set-flags
    (foreign-procedure "qt_graphics_item_set_flags" (void* int) void))
  (define ffi-qt-graphics-item-set-tooltip
    (foreign-procedure "qt_graphics_item_set_tooltip" (void* string) void))
  (define ffi-qt-graphics-item-set-zvalue
    (foreign-procedure "qt_graphics_item_set_zvalue" (void* double) void))
  (define ffi-qt-graphics-item-zvalue
    (foreign-procedure "qt_graphics_item_zvalue" (void*) double))
  (define ffi-qt-graphics-item-set-rotation
    (foreign-procedure "qt_graphics_item_set_rotation" (void* double) void))
  (define ffi-qt-graphics-item-set-scale
    (foreign-procedure "qt_graphics_item_set_scale" (void* double) void))
  (define ffi-qt-graphics-item-set-visible
    (foreign-procedure "qt_graphics_item_set_visible" (void* int) void))

  ;; -----------------------------------------------------------------------
  ;; Paint Widget
  ;; -----------------------------------------------------------------------

  (define ffi-qt-paint-widget-create
    (foreign-procedure "qt_paint_widget_create" (void*) void*))
  (define ffi-qt-paint-widget-on-paint
    (foreign-procedure "chez_qt_paint_widget_on_paint" (void* long) void))
  (define ffi-qt-paint-widget-painter
    (foreign-procedure "qt_paint_widget_painter" (void*) void*))
  (define ffi-qt-paint-widget-update
    (foreign-procedure "qt_paint_widget_update" (void*) void))
  (define ffi-qt-paint-widget-width
    (foreign-procedure "qt_paint_widget_width" (void*) int))
  (define ffi-qt-paint-widget-height
    (foreign-procedure "qt_paint_widget_height" (void*) int))

  ;; -----------------------------------------------------------------------
  ;; QProcess
  ;; -----------------------------------------------------------------------

  (define ffi-qt-process-create
    (foreign-procedure "qt_process_create" (void*) void*))
  (define ffi-qt-process-start
    (foreign-procedure "qt_process_start" (void* string string) int))
  (define ffi-qt-process-write
    (foreign-procedure "qt_process_write" (void* string) void))
  (define ffi-qt-process-close-write
    (foreign-procedure "qt_process_close_write" (void*) void))
  (define ffi-qt-process-read-stdout
    (foreign-procedure "qt_process_read_stdout" (void*) string))
  (define ffi-qt-process-read-stderr
    (foreign-procedure "qt_process_read_stderr" (void*) string))
  (define ffi-qt-process-wait-for-finished
    (foreign-procedure "qt_process_wait_for_finished" (void* int) int))
  (define ffi-qt-process-exit-code
    (foreign-procedure "qt_process_exit_code" (void*) int))
  (define ffi-qt-process-state
    (foreign-procedure "qt_process_state" (void*) int))
  (define ffi-qt-process-kill
    (foreign-procedure "qt_process_kill" (void*) void))
  (define ffi-qt-process-terminate
    (foreign-procedure "qt_process_terminate" (void*) void))
  (define ffi-qt-process-on-finished
    (foreign-procedure "chez_qt_process_on_finished" (void* long) void))
  (define ffi-qt-process-on-ready-read
    (foreign-procedure "chez_qt_process_on_ready_read" (void* long) void))
  (define ffi-qt-process-destroy
    (foreign-procedure "qt_process_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; QWizard / QWizardPage
  ;; -----------------------------------------------------------------------

  (define ffi-qt-wizard-create
    (foreign-procedure "qt_wizard_create" (void*) void*))
  (define ffi-qt-wizard-add-page
    (foreign-procedure "qt_wizard_add_page" (void* void*) int))
  (define ffi-qt-wizard-set-start-id
    (foreign-procedure "qt_wizard_set_start_id" (void* int) void))
  (define ffi-qt-wizard-current-id
    (foreign-procedure "qt_wizard_current_id" (void*) int))
  (define ffi-qt-wizard-set-title
    (foreign-procedure "qt_wizard_set_title" (void* string) void))
  (define ffi-qt-wizard-exec
    (foreign-procedure "qt_wizard_exec" (void*) int))
  (define ffi-qt-wizard-page-create
    (foreign-procedure "qt_wizard_page_create" (void*) void*))
  (define ffi-qt-wizard-page-set-title
    (foreign-procedure "qt_wizard_page_set_title" (void* string) void))
  (define ffi-qt-wizard-page-set-subtitle
    (foreign-procedure "qt_wizard_page_set_subtitle" (void* string) void))
  (define ffi-qt-wizard-page-set-layout
    (foreign-procedure "qt_wizard_page_set_layout" (void* void*) void))
  (define ffi-qt-wizard-on-current-changed
    (foreign-procedure "chez_qt_wizard_on_current_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; QMdiArea / QMdiSubWindow
  ;; -----------------------------------------------------------------------

  (define ffi-qt-mdi-area-create
    (foreign-procedure "qt_mdi_area_create" (void*) void*))
  (define ffi-qt-mdi-area-add-sub-window
    (foreign-procedure "qt_mdi_area_add_sub_window" (void* void*) void*))
  (define ffi-qt-mdi-area-remove-sub-window
    (foreign-procedure "qt_mdi_area_remove_sub_window" (void* void*) void))
  (define ffi-qt-mdi-area-active-sub-window
    (foreign-procedure "qt_mdi_area_active_sub_window" (void*) void*))
  (define ffi-qt-mdi-area-sub-window-count
    (foreign-procedure "qt_mdi_area_sub_window_count" (void*) int))
  (define ffi-qt-mdi-area-cascade
    (foreign-procedure "qt_mdi_area_cascade" (void*) void))
  (define ffi-qt-mdi-area-tile
    (foreign-procedure "qt_mdi_area_tile" (void*) void))
  (define ffi-qt-mdi-area-set-view-mode
    (foreign-procedure "qt_mdi_area_set_view_mode" (void* int) void))
  (define ffi-qt-mdi-sub-window-set-title
    (foreign-procedure "qt_mdi_sub_window_set_title" (void* string) void))
  (define ffi-qt-mdi-area-on-sub-window-activated
    (foreign-procedure "chez_qt_mdi_area_on_sub_window_activated" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; QDial
  ;; -----------------------------------------------------------------------

  (define ffi-qt-dial-create
    (foreign-procedure "qt_dial_create" (void*) void*))
  (define ffi-qt-dial-set-value
    (foreign-procedure "qt_dial_set_value" (void* int) void))
  (define ffi-qt-dial-value
    (foreign-procedure "qt_dial_value" (void*) int))
  (define ffi-qt-dial-set-range
    (foreign-procedure "qt_dial_set_range" (void* int int) void))
  (define ffi-qt-dial-set-notches-visible
    (foreign-procedure "qt_dial_set_notches_visible" (void* int) void))
  (define ffi-qt-dial-set-wrapping
    (foreign-procedure "qt_dial_set_wrapping" (void* int) void))
  (define ffi-qt-dial-on-value-changed
    (foreign-procedure "chez_qt_dial_on_value_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; QLCDNumber
  ;; -----------------------------------------------------------------------

  (define ffi-qt-lcd-create
    (foreign-procedure "qt_lcd_create" (int void*) void*))
  (define ffi-qt-lcd-display-int
    (foreign-procedure "qt_lcd_display_int" (void* int) void))
  (define ffi-qt-lcd-display-double
    (foreign-procedure "qt_lcd_display_double" (void* double) void))
  (define ffi-qt-lcd-display-string
    (foreign-procedure "qt_lcd_display_string" (void* string) void))
  (define ffi-qt-lcd-set-mode
    (foreign-procedure "qt_lcd_set_mode" (void* int) void))
  (define ffi-qt-lcd-set-segment-style
    (foreign-procedure "qt_lcd_set_segment_style" (void* int) void))

  ;; -----------------------------------------------------------------------
  ;; QToolBox
  ;; -----------------------------------------------------------------------

  (define ffi-qt-tool-box-create
    (foreign-procedure "qt_tool_box_create" (void*) void*))
  (define ffi-qt-tool-box-add-item
    (foreign-procedure "qt_tool_box_add_item" (void* void* string) int))
  (define ffi-qt-tool-box-set-current-index
    (foreign-procedure "qt_tool_box_set_current_index" (void* int) void))
  (define ffi-qt-tool-box-current-index
    (foreign-procedure "qt_tool_box_current_index" (void*) int))
  (define ffi-qt-tool-box-count
    (foreign-procedure "qt_tool_box_count" (void*) int))
  (define ffi-qt-tool-box-set-item-text
    (foreign-procedure "qt_tool_box_set_item_text" (void* int string) void))
  (define ffi-qt-tool-box-on-current-changed
    (foreign-procedure "chez_qt_tool_box_on_current_changed" (void* long) void))

  ;; -----------------------------------------------------------------------
  ;; QUndoStack
  ;; -----------------------------------------------------------------------

  (define ffi-qt-undo-stack-create
    (foreign-procedure "qt_undo_stack_create" (void*) void*))
  (define ffi-qt-undo-stack-push
    (foreign-procedure "qt_undo_stack_push" (void* string void* long void* long void* long) void))
  (define ffi-qt-undo-stack-undo
    (foreign-procedure "qt_undo_stack_undo" (void*) void))
  (define ffi-qt-undo-stack-redo
    (foreign-procedure "qt_undo_stack_redo" (void*) void))
  (define ffi-qt-undo-stack-can-undo
    (foreign-procedure "qt_undo_stack_can_undo" (void*) int))
  (define ffi-qt-undo-stack-can-redo
    (foreign-procedure "qt_undo_stack_can_redo" (void*) int))
  (define ffi-qt-undo-stack-undo-text
    (foreign-procedure "qt_undo_stack_undo_text" (void*) string))
  (define ffi-qt-undo-stack-redo-text
    (foreign-procedure "qt_undo_stack_redo_text" (void*) string))
  (define ffi-qt-undo-stack-clear
    (foreign-procedure "qt_undo_stack_clear" (void*) void))
  (define ffi-qt-undo-stack-create-undo-action
    (foreign-procedure "qt_undo_stack_create_undo_action" (void* void*) void*))
  (define ffi-qt-undo-stack-create-redo-action
    (foreign-procedure "qt_undo_stack_create_redo_action" (void* void*) void*))
  (define ffi-qt-undo-stack-destroy
    (foreign-procedure "qt_undo_stack_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; QFileSystemModel
  ;; -----------------------------------------------------------------------

  (define ffi-qt-file-system-model-create
    (foreign-procedure "qt_file_system_model_create" (void*) void*))
  (define ffi-qt-file-system-model-set-root-path
    (foreign-procedure "qt_file_system_model_set_root_path" (void* string) void))
  (define ffi-qt-file-system-model-set-filter
    (foreign-procedure "qt_file_system_model_set_filter" (void* int) void))
  (define ffi-qt-file-system-model-set-name-filters
    (foreign-procedure "qt_file_system_model_set_name_filters" (void* string) void))
  (define ffi-qt-file-system-model-file-path
    (foreign-procedure "qt_file_system_model_file_path" (void* int int) string))
  (define ffi-qt-tree-view-set-file-system-root
    (foreign-procedure "qt_tree_view_set_file_system_root" (void* void* string) void))
  (define ffi-qt-file-system-model-destroy
    (foreign-procedure "qt_file_system_model_destroy" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Signal disconnect
  ;; -----------------------------------------------------------------------

  (define ffi-qt-disconnect-all
    (foreign-procedure "qt_disconnect_all" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; QSyntaxHighlighter
  ;; -----------------------------------------------------------------------

  (define ffi-qt-syntax-highlighter-create
    (foreign-procedure "qt_syntax_highlighter_create" (void*) void*))
  (define ffi-qt-syntax-highlighter-destroy
    (foreign-procedure "qt_syntax_highlighter_destroy" (void*) void))
  (define ffi-qt-syntax-highlighter-add-rule
    (foreign-procedure "qt_syntax_highlighter_add_rule" (void* string int int int int int) void))
  (define ffi-qt-syntax-highlighter-add-keywords
    (foreign-procedure "qt_syntax_highlighter_add_keywords" (void* string int int int int int) void))
  (define ffi-qt-syntax-highlighter-add-multiline-rule
    (foreign-procedure "qt_syntax_highlighter_add_multiline_rule" (void* string string int int int int int) void))
  (define ffi-qt-syntax-highlighter-clear-rules
    (foreign-procedure "qt_syntax_highlighter_clear_rules" (void*) void))
  (define ffi-qt-syntax-highlighter-rehighlight
    (foreign-procedure "qt_syntax_highlighter_rehighlight" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Line number area
  ;; -----------------------------------------------------------------------

  (define ffi-qt-line-number-area-create
    (foreign-procedure "qt_line_number_area_create" (void*) void*))
  (define ffi-qt-line-number-area-destroy
    (foreign-procedure "qt_line_number_area_destroy" (void*) void))
  (define ffi-qt-line-number-area-set-visible
    (foreign-procedure "qt_line_number_area_set_visible" (void* int) void))
  (define ffi-qt-line-number-area-set-bg-color
    (foreign-procedure "qt_line_number_area_set_bg_color" (void* int int int) void))
  (define ffi-qt-line-number-area-set-fg-color
    (foreign-procedure "qt_line_number_area_set_fg_color" (void* int int int) void))

  ;; -----------------------------------------------------------------------
  ;; Extra selections
  ;; -----------------------------------------------------------------------

  (define ffi-qt-plain-text-edit-clear-extra-selections
    (foreign-procedure "qt_plain_text_edit_clear_extra_selections" (void*) void))
  (define ffi-qt-plain-text-edit-add-extra-selection-line
    (foreign-procedure "qt_plain_text_edit_add_extra_selection_line" (void* int int int int) void))
  (define ffi-qt-plain-text-edit-add-extra-selection-range
    (foreign-procedure "qt_plain_text_edit_add_extra_selection_range" (void* int int int int int int int int int) void))
  (define ffi-qt-plain-text-edit-apply-extra-selections
    (foreign-procedure "qt_plain_text_edit_apply_extra_selections" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Completer on editor
  ;; -----------------------------------------------------------------------

  (define ffi-qt-completer-set-widget
    (foreign-procedure "qt_completer_set_widget" (void* void*) void))
  (define ffi-qt-completer-complete-rect
    (foreign-procedure "qt_completer_complete_rect" (void* int int int int) void))

  ;; -----------------------------------------------------------------------
  ;; QScintilla (optional — only available when built with QScintilla support)
  ;; Each binding uses guard to catch missing-entry errors at load time.
  ;; -----------------------------------------------------------------------

  (define (scintilla-unavailable . args)
    (error 'chez-qt "QScintilla not available — rebuild qt_chez_shim with QT_SCINTILLA_AVAILABLE"))

  (define-syntax define-optional-ffi
    (syntax-rules ()
      [(_ name c-name (arg-type ...) ret-type)
       (define name
         (if (foreign-entry? c-name)
             (foreign-procedure c-name (arg-type ...) ret-type)
             scintilla-unavailable))]))

  (define-optional-ffi ffi-qt-scintilla-create "qt_scintilla_create" (void*) void*)
  (define-optional-ffi ffi-qt-scintilla-destroy "qt_scintilla_destroy" (void*) void)
  (define-optional-ffi ffi-qt-scintilla-send-message "qt_scintilla_send_message" (void* unsigned unsigned-long long) long)
  (define-optional-ffi ffi-qt-scintilla-send-message-string "qt_scintilla_send_message_string" (void* unsigned unsigned-long string) long)
  (define-optional-ffi ffi-qt-scintilla-receive-string "qt_scintilla_receive_string" (void* unsigned unsigned-long) string)
  (define-optional-ffi ffi-qt-scintilla-set-text "qt_scintilla_set_text" (void* string) void)
  (define-optional-ffi ffi-qt-scintilla-get-text "qt_scintilla_get_text" (void*) string)
  (define-optional-ffi ffi-qt-scintilla-get-text-length "qt_scintilla_get_text_length" (void*) int)
  (define-optional-ffi ffi-qt-scintilla-set-lexer-language "qt_scintilla_set_lexer_language" (void* string) void)
  (define-optional-ffi ffi-qt-scintilla-get-lexer-language "qt_scintilla_get_lexer_language" (void*) string)
  (define-optional-ffi ffi-qt-scintilla-lexer-set-color "qt_scintilla_lexer_set_color" (void* int int) void)
  (define-optional-ffi ffi-qt-scintilla-lexer-set-paper "qt_scintilla_lexer_set_paper" (void* int int) void)
  (define-optional-ffi ffi-qt-scintilla-lexer-set-font-attr "qt_scintilla_lexer_set_font_attr" (void* int int int) void)
  (define-optional-ffi ffi-qt-scintilla-set-read-only "qt_scintilla_set_read_only" (void* int) void)
  (define-optional-ffi ffi-qt-scintilla-is-read-only "qt_scintilla_is_read_only" (void*) int)
  (define-optional-ffi ffi-qt-scintilla-set-margin-width "qt_scintilla_set_margin_width" (void* int int) void)
  (define-optional-ffi ffi-qt-scintilla-set-margin-type "qt_scintilla_set_margin_type" (void* int int) void)
  (define-optional-ffi ffi-qt-scintilla-set-focus "qt_scintilla_set_focus" (void*) void)
  (define-optional-ffi ffi-qt-scintilla-on-text-changed "chez_qt_scintilla_on_text_changed" (void* long) void)
  (define-optional-ffi ffi-qt-scintilla-on-char-added "chez_qt_scintilla_on_char_added" (void* long) void)
  (define-optional-ffi ffi-qt-scintilla-on-save-point-reached "chez_qt_scintilla_on_save_point_reached" (void* long) void)
  (define-optional-ffi ffi-qt-scintilla-on-save-point-left "chez_qt_scintilla_on_save_point_left" (void* long) void)
  (define-optional-ffi ffi-qt-scintilla-on-margin-clicked "chez_qt_scintilla_on_margin_clicked" (void* long) void)
  (define-optional-ffi ffi-qt-scintilla-on-modified "chez_qt_scintilla_on_modified" (void* long) void)

  ;; -----------------------------------------------------------------------
  ;; Additional Constants
  ;; -----------------------------------------------------------------------

  ;; Frame shape (QFrame::Shape)
  (define ffi-qt-const-frame-no-frame      0)
  (define ffi-qt-const-frame-box           1)
  (define ffi-qt-const-frame-panel         2)
  (define ffi-qt-const-frame-win-panel     3)
  (define ffi-qt-const-frame-hline         4)
  (define ffi-qt-const-frame-vline         5)
  (define ffi-qt-const-frame-styled-panel  6)

  ;; Frame shadow (QFrame::Shadow)
  (define ffi-qt-const-frame-plain   #x0010)
  (define ffi-qt-const-frame-raised  #x0020)
  (define ffi-qt-const-frame-sunken  #x0030)

  ;; Button box standard buttons
  (define ffi-qt-const-button-ok       #x00000400)
  (define ffi-qt-const-button-cancel   #x00400000)
  (define ffi-qt-const-button-apply    #x02000000)
  (define ffi-qt-const-button-close    #x00200000)
  (define ffi-qt-const-button-yes      #x00004000)
  (define ffi-qt-const-button-no       #x00010000)
  (define ffi-qt-const-button-reset    #x04000000)
  (define ffi-qt-const-button-help     #x01000000)
  (define ffi-qt-const-button-save     #x00000800)
  (define ffi-qt-const-button-discard  #x00800000)

  ;; Button box roles
  (define ffi-qt-const-button-role-invalid       -1)
  (define ffi-qt-const-button-role-accept         0)
  (define ffi-qt-const-button-role-reject         1)
  (define ffi-qt-const-button-role-destructive    2)
  (define ffi-qt-const-button-role-action         3)
  (define ffi-qt-const-button-role-help           4)
  (define ffi-qt-const-button-role-yes            5)
  (define ffi-qt-const-button-role-no             6)
  (define ffi-qt-const-button-role-apply          8)
  (define ffi-qt-const-button-role-reset          7)

  ;; Day-of-week (Qt::DayOfWeek)
  (define ffi-qt-const-monday     1)
  (define ffi-qt-const-tuesday    2)
  (define ffi-qt-const-wednesday  3)
  (define ffi-qt-const-thursday   4)
  (define ffi-qt-const-friday     5)
  (define ffi-qt-const-saturday   6)
  (define ffi-qt-const-sunday     7)

  ;; QSettings format
  (define ffi-qt-const-settings-native  0)
  (define ffi-qt-const-settings-ini     1)

  ;; QCompleter completion mode
  (define ffi-qt-const-completer-popup             0)
  (define ffi-qt-const-completer-inline            1)
  (define ffi-qt-const-completer-unfiltered-popup  2)

  ;; Case sensitivity
  (define ffi-qt-const-case-insensitive  0)
  (define ffi-qt-const-case-sensitive    1)

  ;; Match filter mode
  (define ffi-qt-const-match-starts-with  0)
  (define ffi-qt-const-match-contains     1)
  (define ffi-qt-const-match-ends-with    2)

  ;; Validator state
  (define ffi-qt-const-validator-invalid       0)
  (define ffi-qt-const-validator-intermediate  1)
  (define ffi-qt-const-validator-acceptable    2)

  ;; PlainTextEdit line wrap
  (define ffi-qt-const-plain-no-wrap      0)
  (define ffi-qt-const-plain-widget-wrap  1)

  ;; ToolButton popup modes
  (define ffi-qt-const-delayed-popup       0)
  (define ffi-qt-const-menu-button-popup   1)
  (define ffi-qt-const-instant-popup       2)

  ;; ToolButton arrow types
  (define ffi-qt-const-no-arrow     0)
  (define ffi-qt-const-up-arrow     1)
  (define ffi-qt-const-down-arrow   2)
  (define ffi-qt-const-left-arrow   3)
  (define ffi-qt-const-right-arrow  4)

  ;; ToolButton styles
  (define ffi-qt-const-tool-button-icon-only         0)
  (define ffi-qt-const-tool-button-text-only         1)
  (define ffi-qt-const-tool-button-text-beside-icon  2)
  (define ffi-qt-const-tool-button-text-under-icon   3)

  ;; QSizePolicy
  (define ffi-qt-const-size-fixed              0)
  (define ffi-qt-const-size-minimum            1)
  (define ffi-qt-const-size-minimum-expanding  3)
  (define ffi-qt-const-size-maximum            4)
  (define ffi-qt-const-size-preferred          5)
  (define ffi-qt-const-size-expanding          7)
  (define ffi-qt-const-size-ignored            13)

  ;; Graphics item flags
  (define ffi-qt-const-item-movable     #x1)
  (define ffi-qt-const-item-selectable  #x2)
  (define ffi-qt-const-item-focusable   #x4)

  ;; Graphics view drag modes
  (define ffi-qt-const-drag-none         0)
  (define ffi-qt-const-drag-scroll       1)
  (define ffi-qt-const-drag-rubber-band  2)

  ;; Render hints
  (define ffi-qt-const-render-antialiasing       #x01)
  (define ffi-qt-const-render-smooth-pixmap      #x02)
  (define ffi-qt-const-render-text-antialiasing   #x04)

  ;; QProcess state
  (define ffi-qt-const-process-not-running  0)
  (define ffi-qt-const-process-starting     1)
  (define ffi-qt-const-process-running      2)

  ;; QMdiArea view mode
  (define ffi-qt-const-mdi-subwindow  0)
  (define ffi-qt-const-mdi-tabbed     1)

  ;; QLCDNumber mode
  (define ffi-qt-const-lcd-dec  0)
  (define ffi-qt-const-lcd-hex  1)
  (define ffi-qt-const-lcd-oct  2)
  (define ffi-qt-const-lcd-bin  3)

  ;; QLCDNumber segment style
  (define ffi-qt-const-lcd-outline  0)
  (define ffi-qt-const-lcd-filled   1)
  (define ffi-qt-const-lcd-flat     2)

  ;; QDir filter flags
  (define ffi-qt-const-dir-dirs                #x001)
  (define ffi-qt-const-dir-files               #x002)
  (define ffi-qt-const-dir-hidden              #x100)
  (define ffi-qt-const-dir-no-dot-and-dot-dot  #x1000)

  ;; QTextCursor::MoveOperation
  (define ffi-qt-const-cursor-no-move          0)
  (define ffi-qt-const-cursor-start            1)
  (define ffi-qt-const-cursor-up               2)
  (define ffi-qt-const-cursor-start-of-line    3)
  (define ffi-qt-const-cursor-start-of-block   4)
  (define ffi-qt-const-cursor-previous-char    5)
  (define ffi-qt-const-cursor-previous-block   6)
  (define ffi-qt-const-cursor-end-of-line      7)
  (define ffi-qt-const-cursor-end-of-block     8)
  (define ffi-qt-const-cursor-next-char        9)
  (define ffi-qt-const-cursor-next-block      10)
  (define ffi-qt-const-cursor-end             11)
  (define ffi-qt-const-cursor-down            12)
  (define ffi-qt-const-cursor-left            13)
  (define ffi-qt-const-cursor-word-left       14)
  (define ffi-qt-const-cursor-next-word       15)
  (define ffi-qt-const-cursor-right           16)
  (define ffi-qt-const-cursor-word-right      17)
  (define ffi-qt-const-cursor-previous-word   18)

  ;; QTextCursor::MoveMode
  (define ffi-qt-const-move-anchor  0)
  (define ffi-qt-const-keep-anchor  1)

  ;; QTextDocument::FindFlag
  (define ffi-qt-const-find-backward        1)
  (define ffi-qt-const-find-case-sensitive   2)
  (define ffi-qt-const-find-whole-words      4)

  ;; Dock area (Qt::DockWidgetArea)
  (define ffi-qt-const-dock-left    1)
  (define ffi-qt-const-dock-right   2)
  (define ffi-qt-const-dock-top     4)
  (define ffi-qt-const-dock-bottom  8)

  ;; Tray icon message type
  (define ffi-qt-const-tray-no-icon       0)
  (define ffi-qt-const-tray-information   1)
  (define ffi-qt-const-tray-warning       2)
  (define ffi-qt-const-tray-critical      3)

  ;; Key constants (Qt::Key)
  (define ffi-qt-const-key-escape      #x01000000)
  (define ffi-qt-const-key-tab         #x01000001)
  (define ffi-qt-const-key-backtab     #x01000002)
  (define ffi-qt-const-key-backspace   #x01000003)
  (define ffi-qt-const-key-return      #x01000004)
  (define ffi-qt-const-key-enter       #x01000005)
  (define ffi-qt-const-key-insert      #x01000006)
  (define ffi-qt-const-key-delete      #x01000007)
  (define ffi-qt-const-key-pause       #x01000008)
  (define ffi-qt-const-key-home        #x01000010)
  (define ffi-qt-const-key-end         #x01000011)
  (define ffi-qt-const-key-left        #x01000012)
  (define ffi-qt-const-key-up          #x01000013)
  (define ffi-qt-const-key-right       #x01000014)
  (define ffi-qt-const-key-down        #x01000015)
  (define ffi-qt-const-key-page-up     #x01000016)
  (define ffi-qt-const-key-page-down   #x01000017)
  (define ffi-qt-const-key-f1          #x01000030)
  (define ffi-qt-const-key-f2          #x01000031)
  (define ffi-qt-const-key-f3          #x01000032)
  (define ffi-qt-const-key-f4          #x01000033)
  (define ffi-qt-const-key-f5          #x01000034)
  (define ffi-qt-const-key-f6          #x01000035)
  (define ffi-qt-const-key-f7          #x01000036)
  (define ffi-qt-const-key-f8          #x01000037)
  (define ffi-qt-const-key-f9          #x01000038)
  (define ffi-qt-const-key-f10         #x01000039)
  (define ffi-qt-const-key-f11         #x0100003a)
  (define ffi-qt-const-key-f12         #x0100003b)
  (define ffi-qt-const-key-space       #x20)

  ;; Keyboard modifiers (Qt::KeyboardModifier)
  (define ffi-qt-const-mod-none      #x00000000)
  (define ffi-qt-const-mod-shift     #x02000000)
  (define ffi-qt-const-mod-control   #x04000000)
  (define ffi-qt-const-mod-alt       #x08000000)
  (define ffi-qt-const-mod-meta      #x10000000)

  ;; Selection mode (QAbstractItemView::SelectionMode)
  (define ffi-qt-const-select-no-selection        0)
  (define ffi-qt-const-select-single              1)
  (define ffi-qt-const-select-multi               2)
  (define ffi-qt-const-select-extended            3)
  (define ffi-qt-const-select-contiguous          4)

  ;; Selection behavior (QAbstractItemView::SelectionBehavior)
  (define ffi-qt-const-select-items   0)
  (define ffi-qt-const-select-rows    1)
  (define ffi-qt-const-select-columns 2)

  ;; Edit triggers (QAbstractItemView::EditTriggers)
  (define ffi-qt-const-no-edit-triggers  0)
  (define ffi-qt-const-edit-double-click 2)
  (define ffi-qt-const-edit-selected-click 4)
  (define ffi-qt-const-edit-any-key-pressed 16)
  (define ffi-qt-const-edit-all-triggers 31)

  ;; Sort order (Qt::SortOrder)
  (define ffi-qt-const-sort-ascending   0)
  (define ffi-qt-const-sort-descending  1)

  ;; Header resize mode (QHeaderView::ResizeMode)
  (define ffi-qt-const-header-interactive        0)
  (define ffi-qt-const-header-stretch            1)
  (define ffi-qt-const-header-fixed              2)
  (define ffi-qt-const-header-resize-to-contents 3)

  ;; Check state (Qt::CheckState)
  (define ffi-qt-const-unchecked          0)
  (define ffi-qt-const-partially-checked  1)
  (define ffi-qt-const-checked            2)

  ;; ListView flow (QListView::Flow)
  (define ffi-qt-const-flow-top-to-bottom  0)
  (define ffi-qt-const-flow-left-to-right  1)

) ;; end library
