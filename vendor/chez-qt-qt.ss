;;; qt.ss — High-level idiomatic Chez Scheme API for Qt
;;;
;;; Provides API parity with gerbil-qt's qt.ss:
;;;   - Lifecycle: qt-app-create, qt-app-exec!, with-qt-app
;;;   - Widgets: labels, buttons, line edits, combos, etc.
;;;   - Signals: qt-on-clicked!, qt-on-text-changed!, etc.
;;;   - Layouts: vbox, hbox, grid
;;;   - Menus, actions, toolbars
;;;   - Dialogs, message boxes, file dialogs
;;;   - Tree, list, table, tab widgets
;;;   - Timer, clipboard, keyboard events
;;;   - Pixmap, icon, font, color
;;;   - Radio buttons, button groups, group boxes
;;;   - Scroll areas, splitters, progress bars, sliders

(library (chez-qt qt)
  (export
    ;; Lifecycle
    qt-app-create qt-app-exec! qt-app-quit!
    qt-app-process-events! qt-app-destroy!
    with-qt-app

    ;; Widget
    qt-widget-create qt-widget-show! qt-widget-hide! qt-widget-close!
    qt-widget-set-enabled! qt-widget-enabled?
    qt-widget-set-visible! qt-widget-visible?
    qt-widget-set-fixed-size! qt-widget-set-minimum-size!
    qt-widget-set-maximum-size!
    qt-widget-set-minimum-width! qt-widget-set-minimum-height!
    qt-widget-set-maximum-width! qt-widget-set-maximum-height!
    qt-widget-set-cursor! qt-widget-unset-cursor!
    qt-widget-resize! qt-widget-set-style-sheet!
    qt-widget-set-tooltip! qt-widget-set-font-size!
    qt-widget-destroy!

    ;; Main Window
    qt-main-window-create qt-main-window-set-title!
    qt-main-window-set-central-widget!

    ;; Layouts
    qt-vbox-layout-create qt-hbox-layout-create
    qt-layout-add-widget! qt-layout-add-stretch!
    qt-layout-set-spacing! qt-layout-set-margins!

    ;; Labels
    qt-label-create qt-label-set-text! qt-label-text
    qt-label-set-alignment! qt-label-set-word-wrap!

    ;; Push Button
    qt-push-button-create qt-push-button-set-text! qt-push-button-text
    qt-on-clicked!

    ;; Line Edit
    qt-line-edit-create qt-line-edit-text qt-line-edit-set-text!
    qt-line-edit-set-placeholder! qt-line-edit-set-read-only!
    qt-line-edit-set-echo-mode!
    qt-on-text-changed! qt-on-return-pressed!

    ;; Check Box
    qt-check-box-create qt-check-box-checked? qt-check-box-set-checked!
    qt-check-box-set-text! qt-on-toggled!

    ;; Combo Box
    qt-combo-box-create qt-combo-box-add-item! qt-combo-box-set-current-index!
    qt-combo-box-current-index qt-combo-box-current-text
    qt-combo-box-count qt-combo-box-clear!
    qt-on-index-changed!

    ;; Text Edit
    qt-text-edit-create qt-text-edit-text qt-text-edit-set-text!
    qt-text-edit-set-placeholder! qt-text-edit-set-read-only!
    qt-text-edit-append! qt-text-edit-clear!
    qt-text-edit-scroll-to-bottom! qt-text-edit-html
    qt-on-text-edit-changed!

    ;; Spin Box
    qt-spin-box-create qt-spin-box-value qt-spin-box-set-value!
    qt-spin-box-set-range! qt-spin-box-set-single-step!
    qt-spin-box-set-prefix! qt-spin-box-set-suffix!
    qt-on-value-changed!

    ;; Dialog
    qt-dialog-create qt-dialog-exec! qt-dialog-accept! qt-dialog-reject!
    qt-dialog-set-title!

    ;; Message Box
    qt-message-box-information qt-message-box-warning
    qt-message-box-question qt-message-box-critical

    ;; File Dialog
    qt-file-dialog-open-file qt-file-dialog-save-file
    qt-file-dialog-open-directory

    ;; Menu Bar
    qt-main-window-menu-bar

    ;; Menu
    qt-menu-bar-add-menu qt-menu-add-menu
    qt-menu-add-action! qt-menu-add-separator!

    ;; Action
    qt-action-create qt-action-text qt-action-set-text!
    qt-action-set-shortcut! qt-action-set-enabled! qt-action-enabled?
    qt-action-set-checkable! qt-action-checkable?
    qt-action-set-checked! qt-action-checked?
    qt-action-set-tooltip! qt-action-set-status-tip!
    qt-on-triggered! qt-on-action-toggled!

    ;; Toolbar
    qt-toolbar-create qt-main-window-add-toolbar!
    qt-toolbar-add-action! qt-toolbar-add-separator!
    qt-toolbar-add-widget! qt-toolbar-set-movable!
    qt-toolbar-set-icon-size!

    ;; Status Bar
    qt-main-window-set-status-bar-text!

    ;; Grid Layout
    qt-grid-layout-create qt-grid-layout-add-widget!
    qt-grid-layout-set-row-stretch! qt-grid-layout-set-column-stretch!
    qt-grid-layout-set-row-minimum-height!
    qt-grid-layout-set-column-minimum-width!

    ;; Timer
    qt-timer-create qt-timer-start! qt-timer-stop!
    qt-timer-set-single-shot! qt-timer-active?
    qt-timer-interval qt-timer-set-interval!
    qt-on-timeout! qt-timer-single-shot!
    qt-timer-destroy!

    ;; Clipboard
    qt-clipboard-text qt-clipboard-set-text! qt-on-clipboard-changed!

    ;; Tree Widget
    qt-tree-widget-create qt-tree-widget-set-column-count!
    qt-tree-widget-column-count qt-tree-widget-set-header-label!
    qt-tree-widget-set-header-item-text!
    qt-tree-widget-add-top-level-item! qt-tree-widget-top-level-item-count
    qt-tree-widget-top-level-item qt-tree-widget-current-item
    qt-tree-widget-set-current-item!
    qt-tree-widget-expand-item! qt-tree-widget-collapse-item!
    qt-tree-widget-expand-all! qt-tree-widget-collapse-all!
    qt-tree-widget-clear!
    qt-on-current-item-changed! qt-on-tree-item-double-clicked!
    qt-on-item-expanded! qt-on-item-collapsed!

    ;; Tree Widget Item
    qt-tree-item-create qt-tree-item-set-text! qt-tree-item-text
    qt-tree-item-add-child! qt-tree-item-child-count
    qt-tree-item-child qt-tree-item-parent
    qt-tree-item-set-expanded! qt-tree-item-expanded?

    ;; List Widget
    qt-list-widget-create qt-list-widget-add-item!
    qt-list-widget-insert-item! qt-list-widget-remove-item!
    qt-list-widget-current-row qt-list-widget-set-current-row!
    qt-list-widget-item-text qt-list-widget-count qt-list-widget-clear!
    qt-list-widget-set-item-data! qt-list-widget-item-data
    qt-on-current-row-changed! qt-on-item-double-clicked!

    ;; Table Widget
    qt-table-widget-create qt-table-widget-set-item!
    qt-table-widget-item-text
    qt-table-widget-set-horizontal-header! qt-table-widget-set-vertical-header!
    qt-table-widget-set-row-count! qt-table-widget-set-column-count!
    qt-table-widget-row-count qt-table-widget-column-count
    qt-table-widget-current-row qt-table-widget-current-column
    qt-table-widget-clear! qt-on-cell-clicked!

    ;; Tab Widget
    qt-tab-widget-create qt-tab-widget-add-tab!
    qt-tab-widget-set-current-index! qt-tab-widget-current-index
    qt-tab-widget-count qt-tab-widget-set-tab-text!
    qt-on-tab-changed!

    ;; Progress Bar
    qt-progress-bar-create qt-progress-bar-set-value!
    qt-progress-bar-value qt-progress-bar-set-range!
    qt-progress-bar-set-format!

    ;; Slider
    qt-slider-create qt-slider-set-value! qt-slider-value
    qt-slider-set-range! qt-slider-set-single-step!
    qt-slider-set-tick-interval! qt-slider-set-tick-position!
    qt-on-slider-value-changed!

    ;; Window State
    qt-widget-show-minimized! qt-widget-show-maximized!
    qt-widget-show-fullscreen! qt-widget-show-normal!
    qt-widget-window-state qt-widget-move!
    qt-widget-x qt-widget-y qt-widget-width qt-widget-height
    qt-widget-set-focus!

    ;; App-wide Style Sheet
    qt-app-set-style-sheet!

    ;; Scroll Area
    qt-scroll-area-create qt-scroll-area-set-widget!
    qt-scroll-area-set-widget-resizable!
    qt-scroll-area-set-horizontal-scrollbar-policy!
    qt-scroll-area-set-vertical-scrollbar-policy!

    ;; Splitter
    qt-splitter-create qt-splitter-add-widget! qt-splitter-insert-widget!
    qt-splitter-index-of qt-splitter-widget qt-splitter-count
    qt-splitter-set-sizes! qt-splitter-size-at
    qt-splitter-set-stretch-factor! qt-splitter-set-handle-width!
    qt-splitter-set-collapsible! qt-splitter-collapsible?
    qt-splitter-set-orientation!

    ;; Keyboard Events
    qt-on-key-press! qt-on-key-press-consuming!
    qt-last-key-code qt-last-key-modifiers qt-last-key-text

    ;; Pixmap
    qt-pixmap-load qt-pixmap-width qt-pixmap-height
    qt-pixmap-null? qt-pixmap-scaled qt-pixmap-destroy!
    qt-label-set-pixmap!

    ;; Icon
    qt-icon-create qt-icon-create-from-pixmap
    qt-icon-null? qt-icon-destroy!
    qt-push-button-set-icon! qt-action-set-icon!
    qt-widget-set-window-icon!

    ;; Radio Button
    qt-radio-button-create qt-radio-button-text qt-radio-button-set-text!
    qt-radio-button-checked? qt-radio-button-set-checked!
    qt-on-radio-toggled!

    ;; Button Group
    qt-button-group-create qt-button-group-add-button!
    qt-button-group-remove-button! qt-button-group-checked-id
    qt-button-group-set-exclusive! qt-button-group-exclusive?
    qt-on-button-group-clicked! qt-button-group-destroy!

    ;; Group Box
    qt-group-box-create qt-group-box-title qt-group-box-set-title!
    qt-group-box-set-checkable! qt-group-box-checkable?
    qt-group-box-set-checked! qt-group-box-checked?
    qt-on-group-box-toggled!

    ;; Font
    qt-font-create qt-font-family qt-font-point-size
    qt-font-bold? qt-font-set-bold! qt-font-italic? qt-font-set-italic!
    qt-font-destroy! qt-widget-set-font! qt-widget-font

    ;; Color
    qt-color-create qt-color-create-name
    qt-color-red qt-color-green qt-color-blue qt-color-alpha
    qt-color-name qt-color-valid? qt-color-destroy!

    ;; Font Dialog / Color Dialog
    qt-font-dialog-get-font qt-color-dialog-get-color

    ;; Stacked Widget
    qt-stacked-widget-create qt-stacked-widget-add-widget!
    qt-stacked-widget-set-current-index! qt-stacked-widget-current-index
    qt-stacked-widget-count qt-on-stacked-current-changed!

    ;; Dock Widget
    qt-dock-widget-create qt-dock-widget-set-widget! qt-dock-widget-widget
    qt-dock-widget-set-title! qt-dock-widget-title
    qt-dock-widget-set-floating! qt-dock-widget-floating?
    qt-main-window-add-dock-widget!

    ;; System Tray Icon
    qt-system-tray-icon-create qt-system-tray-icon-set-tooltip!
    qt-system-tray-icon-set-icon! qt-system-tray-icon-show!
    qt-system-tray-icon-hide! qt-system-tray-icon-show-message!
    qt-system-tray-icon-set-context-menu! qt-on-tray-activated!
    qt-system-tray-icon-available? qt-system-tray-icon-destroy!

    ;; QPainter
    qt-pixmap-create-blank qt-pixmap-fill!
    qt-painter-create qt-painter-end! qt-painter-destroy!
    qt-painter-set-pen-color! qt-painter-set-pen-width!
    qt-painter-set-brush-color! qt-painter-set-font!
    qt-painter-set-antialiasing!
    qt-painter-draw-line! qt-painter-draw-rect! qt-painter-fill-rect!
    qt-painter-draw-ellipse! qt-painter-draw-text! qt-painter-draw-text-rect!
    qt-painter-draw-pixmap! qt-painter-draw-point! qt-painter-draw-arc!
    qt-painter-save! qt-painter-restore!
    qt-painter-translate! qt-painter-rotate! qt-painter-scale!
    with-painter

    ;; Drag and Drop
    qt-widget-set-accept-drops! qt-drop-filter-install!
    qt-drop-filter-last-text qt-drop-filter-destroy! qt-drag-text!

    ;; Double Spin Box
    qt-double-spin-box-create qt-double-spin-box-set-value!
    qt-double-spin-box-value qt-double-spin-box-set-range!
    qt-double-spin-box-set-single-step! qt-double-spin-box-set-decimals!
    qt-double-spin-box-decimals qt-double-spin-box-set-prefix!
    qt-double-spin-box-set-suffix! qt-on-double-spin-value-changed!

    ;; Date Edit
    qt-date-edit-create qt-date-edit-set-date!
    qt-date-edit-year qt-date-edit-month qt-date-edit-day
    qt-date-edit-date-string qt-date-edit-set-minimum-date!
    qt-date-edit-set-maximum-date! qt-date-edit-set-calendar-popup!
    qt-date-edit-set-display-format! qt-on-date-changed!

    ;; Time Edit
    qt-time-edit-create qt-time-edit-set-time!
    qt-time-edit-hour qt-time-edit-minute qt-time-edit-second
    qt-time-edit-time-string qt-time-edit-set-display-format!
    qt-on-time-changed!

    ;; Frame
    qt-frame-create qt-frame-set-frame-shape! qt-frame-frame-shape
    qt-frame-set-frame-shadow! qt-frame-frame-shadow
    qt-frame-set-line-width! qt-frame-line-width qt-frame-set-mid-line-width!

    ;; Progress Dialog
    qt-progress-dialog-create qt-progress-dialog-set-value!
    qt-progress-dialog-value qt-progress-dialog-set-range!
    qt-progress-dialog-set-label-text! qt-progress-dialog-was-canceled?
    qt-progress-dialog-set-minimum-duration! qt-progress-dialog-set-auto-close!
    qt-progress-dialog-set-auto-reset! qt-progress-dialog-reset!
    qt-on-progress-canceled!

    ;; Input Dialog
    qt-input-dialog-get-text qt-input-dialog-get-int
    qt-input-dialog-get-double qt-input-dialog-get-item
    qt-input-dialog-was-accepted?

    ;; Form Layout
    qt-form-layout-create qt-form-layout-add-row!
    qt-form-layout-add-row-widget! qt-form-layout-add-spanning-widget!
    qt-form-layout-row-count

    ;; Shortcut
    qt-shortcut-create qt-shortcut-set-key!
    qt-shortcut-set-enabled! qt-shortcut-enabled?
    qt-on-shortcut-activated! qt-shortcut-destroy!

    ;; Text Browser
    qt-text-browser-create qt-text-browser-set-html!
    qt-text-browser-set-plain-text! qt-text-browser-plain-text
    qt-text-browser-set-open-external-links!
    qt-text-browser-set-source! qt-text-browser-source
    qt-text-browser-scroll-to-bottom! qt-text-browser-append!
    qt-text-browser-html qt-on-anchor-clicked!

    ;; Button Box
    qt-button-box-create qt-button-box-button
    qt-button-box-add-button!
    qt-on-button-box-accepted! qt-on-button-box-rejected!
    qt-on-button-box-clicked!

    ;; Calendar
    qt-calendar-create qt-calendar-set-selected-date!
    qt-calendar-selected-year qt-calendar-selected-month qt-calendar-selected-day
    qt-calendar-selected-date-string
    qt-calendar-set-minimum-date! qt-calendar-set-maximum-date!
    qt-calendar-set-first-day-of-week! qt-calendar-set-grid-visible!
    qt-calendar-grid-visible? qt-calendar-set-navigation-bar-visible!
    qt-on-calendar-selection-changed! qt-on-calendar-clicked!

    ;; QSettings
    qt-settings-create qt-settings-create-file
    qt-settings-set-string! qt-settings-value-string
    qt-settings-set-int! qt-settings-value-int
    qt-settings-set-double! qt-settings-value-double
    qt-settings-set-bool! qt-settings-value-bool
    qt-settings-contains? qt-settings-remove!
    qt-settings-all-keys qt-settings-child-keys qt-settings-child-groups
    qt-settings-begin-group! qt-settings-end-group! qt-settings-group
    qt-settings-sync! qt-settings-clear!
    qt-settings-file-name qt-settings-writable? qt-settings-destroy!

    ;; QCompleter
    qt-completer-create qt-completer-set-model-strings!
    qt-completer-set-case-sensitivity! qt-completer-set-completion-mode!
    qt-completer-set-filter-mode! qt-completer-set-max-visible-items!
    qt-completer-completion-count qt-completer-current-completion
    qt-completer-set-completion-prefix!
    qt-on-completer-activated! qt-line-edit-set-completer! qt-completer-destroy!

    ;; Tooltip / WhatsThis
    qt-tooltip-show-text! qt-tooltip-hide-text! qt-tooltip-visible?
    qt-widget-tooltip qt-widget-set-whats-this! qt-widget-whats-this

    ;; QStandardItemModel
    qt-standard-model-create qt-standard-model-destroy!
    qt-standard-model-row-count qt-standard-model-column-count
    qt-standard-model-set-row-count! qt-standard-model-set-column-count!
    qt-standard-model-set-item! qt-standard-model-item
    qt-standard-model-insert-row! qt-standard-model-insert-column!
    qt-standard-model-remove-row! qt-standard-model-remove-column!
    qt-standard-model-clear!
    qt-standard-model-set-horizontal-header! qt-standard-model-set-vertical-header!

    ;; QStandardItem
    qt-standard-item-create qt-standard-item-text qt-standard-item-set-text!
    qt-standard-item-tooltip qt-standard-item-set-tooltip!
    qt-standard-item-set-editable! qt-standard-item-editable?
    qt-standard-item-set-enabled! qt-standard-item-enabled?
    qt-standard-item-set-selectable! qt-standard-item-selectable?
    qt-standard-item-set-checkable! qt-standard-item-checkable?
    qt-standard-item-set-check-state! qt-standard-item-check-state
    qt-standard-item-set-icon!
    qt-standard-item-append-row! qt-standard-item-row-count
    qt-standard-item-column-count qt-standard-item-child

    ;; QStringListModel
    qt-string-list-model-create qt-string-list-model-destroy!
    qt-string-list-model-set-strings! qt-string-list-model-strings
    qt-string-list-model-row-count

    ;; Views (common)
    qt-view-set-model! qt-view-set-selection-mode!
    qt-view-set-selection-behavior! qt-view-set-alternating-row-colors!
    qt-view-set-sorting-enabled! qt-view-set-edit-triggers!

    ;; QListView
    qt-list-view-create qt-list-view-set-flow!

    ;; QTableView
    qt-table-view-create qt-table-view-set-column-width!
    qt-table-view-set-row-height!
    qt-table-view-hide-column! qt-table-view-show-column!
    qt-table-view-hide-row! qt-table-view-show-row!
    qt-table-view-resize-columns-to-contents!
    qt-table-view-resize-rows-to-contents!

    ;; QTreeView
    qt-tree-view-create qt-tree-view-expand-all! qt-tree-view-collapse-all!
    qt-tree-view-set-indentation! qt-tree-view-indentation
    qt-tree-view-set-root-is-decorated! qt-tree-view-set-header-hidden!
    qt-tree-view-set-column-width!

    ;; QHeaderView (via view)
    qt-view-header-set-stretch-last-section!
    qt-view-header-set-section-resize-mode!
    qt-view-header-hide! qt-view-header-show!
    qt-view-header-set-default-section-size!

    ;; QSortFilterProxyModel
    qt-sort-filter-proxy-create qt-sort-filter-proxy-destroy!
    qt-sort-filter-proxy-set-source-model!
    qt-sort-filter-proxy-set-filter-regex!
    qt-sort-filter-proxy-set-filter-column!
    qt-sort-filter-proxy-set-filter-case-sensitivity!
    qt-sort-filter-proxy-set-filter-role!
    qt-sort-filter-proxy-sort! qt-sort-filter-proxy-set-sort-role!
    qt-sort-filter-proxy-set-dynamic-sort-filter!
    qt-sort-filter-proxy-invalidate-filter!
    qt-sort-filter-proxy-row-count

    ;; View signals + selection
    qt-on-view-clicked! qt-on-view-double-clicked!
    qt-on-view-activated! qt-on-view-selection-changed!
    qt-view-last-clicked-row qt-view-last-clicked-col
    qt-view-selected-rows qt-view-current-row

    ;; Validators
    qt-int-validator-create qt-double-validator-create
    qt-regex-validator-create qt-validator-destroy!
    qt-validator-validate qt-line-edit-set-validator!
    qt-line-edit-has-acceptable-input?

    ;; QPlainTextEdit
    qt-plain-text-edit-create qt-plain-text-edit-set-text!
    qt-plain-text-edit-text qt-plain-text-edit-append!
    qt-plain-text-edit-clear! qt-plain-text-edit-set-read-only!
    qt-plain-text-edit-read-only? qt-plain-text-edit-set-placeholder!
    qt-plain-text-edit-line-count qt-plain-text-edit-set-max-block-count!
    qt-plain-text-edit-cursor-line qt-plain-text-edit-cursor-column
    qt-plain-text-edit-set-line-wrap!
    qt-on-plain-text-changed!
    ;; Editor extensions
    qt-plain-text-edit-cursor-position qt-plain-text-edit-set-cursor-position!
    qt-plain-text-edit-move-cursor!
    qt-plain-text-edit-select-all! qt-plain-text-edit-selected-text
    qt-plain-text-edit-selection-start qt-plain-text-edit-selection-end
    qt-plain-text-edit-set-selection! qt-plain-text-edit-has-selection?
    qt-plain-text-edit-insert-text! qt-plain-text-edit-remove-selected-text!
    qt-plain-text-edit-undo! qt-plain-text-edit-redo!
    qt-plain-text-edit-can-undo?
    qt-plain-text-edit-cut! qt-plain-text-edit-copy! qt-plain-text-edit-paste!
    qt-plain-text-edit-text-length qt-plain-text-edit-text-range
    qt-plain-text-edit-line-from-position qt-plain-text-edit-line-end-position
    qt-plain-text-edit-find-text
    qt-plain-text-edit-ensure-cursor-visible! qt-plain-text-edit-center-cursor!
    qt-text-document-create qt-plain-text-document-create
    qt-text-document-destroy!
    qt-plain-text-edit-document qt-plain-text-edit-set-document!
    qt-text-document-modified? qt-text-document-set-modified!

    ;; QToolButton
    qt-tool-button-create qt-tool-button-set-text! qt-tool-button-text
    qt-tool-button-set-icon! qt-tool-button-set-menu!
    qt-tool-button-set-popup-mode! qt-tool-button-set-auto-raise!
    qt-tool-button-set-arrow-type! qt-tool-button-set-tool-button-style!
    qt-on-tool-button-clicked!

    ;; Layout spacers / Size policy
    qt-layout-add-spacing!
    qt-widget-set-size-policy! qt-layout-set-stretch-factor!

    ;; Graphics Scene
    qt-graphics-scene-create qt-graphics-scene-add-rect!
    qt-graphics-scene-add-ellipse! qt-graphics-scene-add-line!
    qt-graphics-scene-add-text! qt-graphics-scene-add-pixmap!
    qt-graphics-scene-remove-item! qt-graphics-scene-clear!
    qt-graphics-scene-items-count qt-graphics-scene-set-background!
    qt-graphics-scene-destroy!

    ;; Graphics View
    qt-graphics-view-create qt-graphics-view-set-render-hint!
    qt-graphics-view-set-drag-mode! qt-graphics-view-fit-in-view!
    qt-graphics-view-scale! qt-graphics-view-center-on!

    ;; Graphics Item
    qt-graphics-item-set-pos! qt-graphics-item-x qt-graphics-item-y
    qt-graphics-item-set-pen! qt-graphics-item-set-brush!
    qt-graphics-item-set-flags! qt-graphics-item-set-tooltip!
    qt-graphics-item-set-zvalue! qt-graphics-item-zvalue
    qt-graphics-item-set-rotation! qt-graphics-item-set-scale!
    qt-graphics-item-set-visible!

    ;; Paint Widget
    qt-paint-widget-create qt-on-paint!
    qt-paint-widget-painter qt-paint-widget-update!
    qt-paint-widget-width qt-paint-widget-height

    ;; QProcess
    qt-process-create qt-process-start! qt-process-write!
    qt-process-close-write! qt-process-read-stdout qt-process-read-stderr
    qt-process-wait-for-finished! qt-process-exit-code qt-process-state
    qt-process-kill! qt-process-terminate!
    qt-on-process-finished! qt-on-process-ready-read! qt-process-destroy!

    ;; QWizard / QWizardPage
    qt-wizard-create qt-wizard-add-page! qt-wizard-set-start-id!
    qt-wizard-current-id qt-wizard-set-title! qt-wizard-exec!
    qt-wizard-page-create qt-wizard-page-set-title!
    qt-wizard-page-set-subtitle! qt-wizard-page-set-layout!
    qt-on-wizard-current-changed!

    ;; QMdiArea / QMdiSubWindow
    qt-mdi-area-create qt-mdi-area-add-sub-window!
    qt-mdi-area-remove-sub-window! qt-mdi-area-active-sub-window
    qt-mdi-area-sub-window-count qt-mdi-area-cascade! qt-mdi-area-tile!
    qt-mdi-area-set-view-mode! qt-mdi-sub-window-set-title!
    qt-on-mdi-sub-window-activated!

    ;; QDial
    qt-dial-create qt-dial-set-value! qt-dial-value
    qt-dial-set-range! qt-dial-set-notches-visible! qt-dial-set-wrapping!
    qt-on-dial-value-changed!

    ;; QLCDNumber
    qt-lcd-create qt-lcd-display-int! qt-lcd-display-double!
    qt-lcd-display-string! qt-lcd-set-mode! qt-lcd-set-segment-style!

    ;; QToolBox
    qt-tool-box-create qt-tool-box-add-item!
    qt-tool-box-set-current-index! qt-tool-box-current-index
    qt-tool-box-count qt-tool-box-set-item-text!
    qt-on-tool-box-current-changed!

    ;; QUndoStack
    qt-undo-stack-create qt-undo-stack-push!
    qt-undo-stack-undo! qt-undo-stack-redo!
    qt-undo-stack-can-undo? qt-undo-stack-can-redo?
    qt-undo-stack-undo-text qt-undo-stack-redo-text
    qt-undo-stack-clear!
    qt-undo-stack-create-undo-action qt-undo-stack-create-redo-action
    qt-undo-stack-destroy!

    ;; QFileSystemModel
    qt-file-system-model-create qt-file-system-model-set-root-path!
    qt-file-system-model-set-filter! qt-file-system-model-set-name-filters!
    qt-file-system-model-file-path qt-tree-view-set-file-system-root!
    qt-file-system-model-destroy!

    ;; QSyntaxHighlighter
    qt-syntax-highlighter-create qt-syntax-highlighter-destroy!
    qt-syntax-highlighter-add-rule! qt-syntax-highlighter-add-keywords!
    qt-syntax-highlighter-add-multiline-rule!
    qt-syntax-highlighter-clear-rules! qt-syntax-highlighter-rehighlight!

    ;; Line number area
    qt-line-number-area-create qt-line-number-area-destroy!
    qt-line-number-area-set-visible!
    qt-line-number-area-set-bg-color! qt-line-number-area-set-fg-color!

    ;; Extra selections
    qt-plain-text-edit-clear-extra-selections!
    qt-plain-text-edit-add-extra-selection-line!
    qt-plain-text-edit-add-extra-selection-range!
    qt-plain-text-edit-apply-extra-selections!

    ;; Completer on editor
    qt-completer-set-widget! qt-completer-complete-rect!

    ;; QScintilla
    qt-scintilla-create qt-scintilla-destroy!
    qt-scintilla-send-message qt-scintilla-send-message-string
    qt-scintilla-receive-string
    qt-scintilla-set-text! qt-scintilla-get-text qt-scintilla-get-text-length
    qt-scintilla-set-lexer-language! qt-scintilla-get-lexer-language
    qt-scintilla-set-read-only! qt-scintilla-read-only?
    qt-scintilla-set-margin-width! qt-scintilla-set-margin-type!
    qt-scintilla-set-focus!
    qt-on-scintilla-text-changed! qt-on-scintilla-char-added!
    qt-on-scintilla-save-point-reached! qt-on-scintilla-save-point-left!
    qt-on-scintilla-margin-clicked! qt-on-scintilla-modified!

    ;; Callback management
    unregister-qt-handler! qt-disconnect-all!

    ;; Constants
    QT_ALIGN_LEFT QT_ALIGN_RIGHT QT_ALIGN_CENTER
    QT_ALIGN_TOP QT_ALIGN_BOTTOM
    QT_ECHO_NORMAL QT_ECHO_NO_ECHO QT_ECHO_PASSWORD QT_ECHO_PASSWORD_ON_EDIT
    QT_HORIZONTAL QT_VERTICAL
    QT_TICKS_NONE QT_TICKS_ABOVE QT_TICKS_BELOW QT_TICKS_BOTH_SIDES
    QT_WINDOW_NO_STATE QT_WINDOW_MINIMIZED QT_WINDOW_MAXIMIZED QT_WINDOW_FULL_SCREEN
    QT_SCROLLBAR_AS_NEEDED QT_SCROLLBAR_ALWAYS_OFF QT_SCROLLBAR_ALWAYS_ON
    QT_CURSOR_ARROW QT_CURSOR_CROSS QT_CURSOR_WAIT QT_CURSOR_IBEAM
    QT_CURSOR_POINTING_HAND QT_CURSOR_FORBIDDEN QT_CURSOR_BUSY
    QT_FRAME_NO_FRAME QT_FRAME_BOX QT_FRAME_PANEL QT_FRAME_WIN_PANEL
    QT_FRAME_HLINE QT_FRAME_VLINE QT_FRAME_STYLED_PANEL
    QT_FRAME_PLAIN QT_FRAME_RAISED QT_FRAME_SUNKEN
    QT_BUTTON_OK QT_BUTTON_CANCEL QT_BUTTON_APPLY QT_BUTTON_CLOSE
    QT_BUTTON_YES QT_BUTTON_NO QT_BUTTON_RESET QT_BUTTON_HELP
    QT_BUTTON_SAVE QT_BUTTON_DISCARD
    QT_BUTTON_ROLE_INVALID QT_BUTTON_ROLE_ACCEPT QT_BUTTON_ROLE_REJECT
    QT_BUTTON_ROLE_DESTRUCTIVE QT_BUTTON_ROLE_ACTION QT_BUTTON_ROLE_HELP
    QT_BUTTON_ROLE_YES QT_BUTTON_ROLE_NO QT_BUTTON_ROLE_APPLY QT_BUTTON_ROLE_RESET
    QT_MONDAY QT_TUESDAY QT_WEDNESDAY QT_THURSDAY QT_FRIDAY QT_SATURDAY QT_SUNDAY
    QT_SETTINGS_NATIVE QT_SETTINGS_INI
    QT_COMPLETER_POPUP QT_COMPLETER_INLINE QT_COMPLETER_UNFILTERED_POPUP
    QT_CASE_INSENSITIVE QT_CASE_SENSITIVE
    QT_MATCH_STARTS_WITH QT_MATCH_CONTAINS QT_MATCH_ENDS_WITH
    QT_VALIDATOR_INVALID QT_VALIDATOR_INTERMEDIATE QT_VALIDATOR_ACCEPTABLE
    QT_PLAIN_NO_WRAP QT_PLAIN_WIDGET_WRAP
    QT_DELAYED_POPUP QT_MENU_BUTTON_POPUP QT_INSTANT_POPUP
    QT_NO_ARROW QT_UP_ARROW QT_DOWN_ARROW QT_LEFT_ARROW QT_RIGHT_ARROW
    QT_TOOL_BUTTON_ICON_ONLY QT_TOOL_BUTTON_TEXT_ONLY
    QT_TOOL_BUTTON_TEXT_BESIDE_ICON QT_TOOL_BUTTON_TEXT_UNDER_ICON
    QT_SIZE_FIXED QT_SIZE_MINIMUM QT_SIZE_MINIMUM_EXPANDING
    QT_SIZE_MAXIMUM QT_SIZE_PREFERRED QT_SIZE_EXPANDING QT_SIZE_IGNORED
    QT_ITEM_MOVABLE QT_ITEM_SELECTABLE QT_ITEM_FOCUSABLE
    QT_DRAG_NONE QT_DRAG_SCROLL QT_DRAG_RUBBER_BAND
    QT_RENDER_ANTIALIASING QT_RENDER_SMOOTH_PIXMAP QT_RENDER_TEXT_ANTIALIASING
    QT_PROCESS_NOT_RUNNING QT_PROCESS_STARTING QT_PROCESS_RUNNING
    QT_MDI_SUBWINDOW QT_MDI_TABBED
    QT_LCD_DEC QT_LCD_HEX QT_LCD_OCT QT_LCD_BIN
    QT_LCD_OUTLINE QT_LCD_FILLED QT_LCD_FLAT
    QT_DIR_DIRS QT_DIR_FILES QT_DIR_HIDDEN QT_DIR_NO_DOT_AND_DOT_DOT
    QT_CURSOR_NO_MOVE QT_CURSOR_START QT_CURSOR_UP
    QT_CURSOR_START_OF_LINE QT_CURSOR_START_OF_BLOCK
    QT_CURSOR_PREVIOUS_CHAR QT_CURSOR_PREVIOUS_BLOCK
    QT_CURSOR_END_OF_LINE QT_CURSOR_END_OF_BLOCK
    QT_CURSOR_NEXT_CHAR QT_CURSOR_NEXT_BLOCK
    QT_CURSOR_END QT_CURSOR_DOWN
    QT_CURSOR_LEFT QT_CURSOR_WORD_LEFT QT_CURSOR_NEXT_WORD
    QT_CURSOR_RIGHT QT_CURSOR_WORD_RIGHT QT_CURSOR_PREVIOUS_WORD
    QT_MOVE_ANCHOR QT_KEEP_ANCHOR
    QT_FIND_BACKWARD QT_FIND_CASE_SENSITIVE QT_FIND_WHOLE_WORDS
    QT_DOCK_LEFT QT_DOCK_RIGHT QT_DOCK_TOP QT_DOCK_BOTTOM
    QT_TRAY_NO_ICON QT_TRAY_INFORMATION QT_TRAY_WARNING QT_TRAY_CRITICAL
    QT_KEY_ESCAPE QT_KEY_TAB QT_KEY_BACKTAB QT_KEY_BACKSPACE
    QT_KEY_RETURN QT_KEY_ENTER QT_KEY_INSERT QT_KEY_DELETE QT_KEY_PAUSE
    QT_KEY_HOME QT_KEY_END QT_KEY_LEFT QT_KEY_UP QT_KEY_RIGHT QT_KEY_DOWN
    QT_KEY_PAGE_UP QT_KEY_PAGE_DOWN
    QT_KEY_F1 QT_KEY_F2 QT_KEY_F3 QT_KEY_F4 QT_KEY_F5 QT_KEY_F6
    QT_KEY_F7 QT_KEY_F8 QT_KEY_F9 QT_KEY_F10 QT_KEY_F11 QT_KEY_F12
    QT_KEY_SPACE
    QT_MOD_NONE QT_MOD_SHIFT QT_MOD_CONTROL QT_MOD_ALT QT_MOD_META
    QT_SELECT_NO_SELECTION QT_SELECT_SINGLE QT_SELECT_MULTI
    QT_SELECT_EXTENDED QT_SELECT_CONTIGUOUS
    QT_SELECT_ITEMS QT_SELECT_ROWS QT_SELECT_COLUMNS
    QT_NO_EDIT_TRIGGERS QT_EDIT_DOUBLE_CLICK QT_EDIT_SELECTED_CLICK
    QT_EDIT_ANY_KEY_PRESSED QT_EDIT_ALL_TRIGGERS
    QT_SORT_ASCENDING QT_SORT_DESCENDING
    QT_HEADER_INTERACTIVE QT_HEADER_STRETCH QT_HEADER_FIXED
    QT_HEADER_RESIZE_TO_CONTENTS
    QT_UNCHECKED QT_PARTIALLY_CHECKED QT_CHECKED
    QT_FLOW_TOP_TO_BOTTOM QT_FLOW_LEFT_TO_RIGHT)

  (import (chezscheme)
          (chez-qt ffi))

  ;; -----------------------------------------------------------------------
  ;; Constants (fetched from FFI at load time)
  ;; -----------------------------------------------------------------------

  (define QT_ALIGN_LEFT    ffi-qt-const-align-left)
  (define QT_ALIGN_RIGHT   ffi-qt-const-align-right)
  (define QT_ALIGN_CENTER  ffi-qt-const-align-center)
  (define QT_ALIGN_TOP     ffi-qt-const-align-top)
  (define QT_ALIGN_BOTTOM  ffi-qt-const-align-bottom)

  (define QT_ECHO_NORMAL          ffi-qt-const-echo-normal)
  (define QT_ECHO_NO_ECHO         ffi-qt-const-echo-no-echo)
  (define QT_ECHO_PASSWORD         ffi-qt-const-echo-password)
  (define QT_ECHO_PASSWORD_ON_EDIT ffi-qt-const-echo-password-on-edit)

  (define QT_HORIZONTAL ffi-qt-const-horizontal)
  (define QT_VERTICAL   ffi-qt-const-vertical)

  (define QT_TICKS_NONE       ffi-qt-const-ticks-none)
  (define QT_TICKS_ABOVE      ffi-qt-const-ticks-above)
  (define QT_TICKS_BELOW      ffi-qt-const-ticks-below)
  (define QT_TICKS_BOTH_SIDES ffi-qt-const-ticks-both-sides)

  (define QT_WINDOW_NO_STATE    ffi-qt-const-window-no-state)
  (define QT_WINDOW_MINIMIZED   ffi-qt-const-window-minimized)
  (define QT_WINDOW_MAXIMIZED   ffi-qt-const-window-maximized)
  (define QT_WINDOW_FULL_SCREEN ffi-qt-const-window-full-screen)

  (define QT_SCROLLBAR_AS_NEEDED  ffi-qt-const-scrollbar-as-needed)
  (define QT_SCROLLBAR_ALWAYS_OFF ffi-qt-const-scrollbar-always-off)
  (define QT_SCROLLBAR_ALWAYS_ON  ffi-qt-const-scrollbar-always-on)

  (define QT_CURSOR_ARROW         ffi-qt-const-cursor-arrow)
  (define QT_CURSOR_CROSS         ffi-qt-const-cursor-cross)
  (define QT_CURSOR_WAIT          ffi-qt-const-cursor-wait)
  (define QT_CURSOR_IBEAM         ffi-qt-const-cursor-ibeam)
  (define QT_CURSOR_POINTING_HAND ffi-qt-const-cursor-pointing-hand)
  (define QT_CURSOR_FORBIDDEN     ffi-qt-const-cursor-forbidden)
  (define QT_CURSOR_BUSY          ffi-qt-const-cursor-busy)

  ;; -----------------------------------------------------------------------
  ;; Callback dispatch tables
  ;; -----------------------------------------------------------------------

  (define *void-handlers*   (make-hashtable equal-hash equal?))
  (define *string-handlers* (make-hashtable equal-hash equal?))
  (define *int-handlers*    (make-hashtable equal-hash equal?))
  (define *bool-handlers*   (make-hashtable equal-hash equal?))
  (define *next-callback-id* 0)

  ;; Widget → list of callback IDs for cleanup
  (define *widget-handlers* (make-hashtable equal-hash equal?))

  (define (next-id!)
    (let ([id *next-callback-id*])
      (set! *next-callback-id* (+ id 1))
      id))

  (define (register-void-handler! handler)
    (let ([id (next-id!)])
      (hashtable-set! *void-handlers* id handler)
      id))

  (define (register-string-handler! handler)
    (let ([id (next-id!)])
      (hashtable-set! *string-handlers* id handler)
      id))

  (define (register-int-handler! handler)
    (let ([id (next-id!)])
      (hashtable-set! *int-handlers* id handler)
      id))

  (define (register-bool-handler! handler)
    (let ([id (next-id!)])
      (hashtable-set! *bool-handlers* id handler)
      id))

  (define (unregister-qt-handler! id)
    (hashtable-delete! *void-handlers* id)
    (hashtable-delete! *string-handlers* id)
    (hashtable-delete! *int-handlers* id)
    (hashtable-delete! *bool-handlers* id))

  (define (track-handler! obj id)
    (let ([ids (hashtable-ref *widget-handlers* obj '())])
      (hashtable-set! *widget-handlers* obj (cons id ids)))
    id)

  (define (qt-disconnect-all! obj)
    (let ([ids (hashtable-ref *widget-handlers* obj '())])
      (for-each unregister-qt-handler! ids)
      (hashtable-delete! *widget-handlers* obj)))

  ;; -----------------------------------------------------------------------
  ;; foreign-callable trampolines (Scheme functions callable from C)
  ;; Each is guarded with guard to prevent Scheme exceptions from
  ;; propagating through C++ frames.
  ;; -----------------------------------------------------------------------

  (define void-trampoline
    (foreign-callable
      (lambda (callback-id)
        (guard (e [#t (display-condition e (current-error-port))
                      (newline (current-error-port))])
          (let ([handler (hashtable-ref *void-handlers* callback-id #f)])
            (when handler (handler)))))
      (long)
      void))

  (define string-trampoline
    (foreign-callable
      (lambda (callback-id value)
        (guard (e [#t (display-condition e (current-error-port))
                      (newline (current-error-port))])
          (let ([handler (hashtable-ref *string-handlers* callback-id #f)])
            (when handler (handler value)))))
      (long string)
      void))

  (define int-trampoline
    (foreign-callable
      (lambda (callback-id value)
        (guard (e [#t (display-condition e (current-error-port))
                      (newline (current-error-port))])
          (let ([handler (hashtable-ref *int-handlers* callback-id #f)])
            (when handler (handler value)))))
      (long int)
      void))

  (define bool-trampoline
    (foreign-callable
      (lambda (callback-id value)
        (guard (e [#t (display-condition e (current-error-port))
                      (newline (current-error-port))])
          (let ([handler (hashtable-ref *bool-handlers* callback-id #f)])
            (when handler (handler (not (zero? value)))))))
      (long int)
      void))

  ;; Lock trampolines and register with C shim
  (define init-trampolines!
    (let ()
      (lock-object void-trampoline)
      (lock-object string-trampoline)
      (lock-object int-trampoline)
      (lock-object bool-trampoline)
      (ffi-set-void-callback (foreign-callable-entry-point void-trampoline))
      (ffi-set-string-callback (foreign-callable-entry-point string-trampoline))
      (ffi-set-int-callback (foreign-callable-entry-point int-trampoline))
      (ffi-set-bool-callback (foreign-callable-entry-point bool-trampoline))
      (void)))

  ;; -----------------------------------------------------------------------
  ;; Lifecycle
  ;; -----------------------------------------------------------------------

  (define (qt-app-create) (ffi-qt-app-create))
  (define (qt-app-exec! app . args)
    ;; qt_application_exec is a no-op in the C shim — the Qt event loop
    ;; runs in a background pthread. Poll until the event loop exits.
    ;; Optional first argument: a tick callback invoked every 50ms iteration.
    ;; This allows the caller to merge periodic work (e.g. master timer) into
    ;; the same Chez thread, eliminating multi-thread GC rendezvous deadlocks.
    (ffi-qt-app-exec app)
    (let ((tick (if (null? args) #f (car args))))
      (let loop ()
        (when (= (ffi-qt-app-is-running) 1)
          (when tick (tick))
          (sleep (make-time 'time-duration 50000000 0))
          (loop)))))
  (define (qt-app-quit! app) (ffi-qt-app-quit app))
  (define (qt-app-process-events! app) (ffi-qt-app-process-events app))

  (define (qt-app-destroy! app)
    (qt-disconnect-all! app)
    (ffi-qt-app-destroy app))

  (define-syntax with-qt-app
    (syntax-rules ()
      [(_ app body ...)
       (let ([app (qt-app-create)])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda () (qt-app-destroy! app))))]))

  ;; -----------------------------------------------------------------------
  ;; Widget
  ;; -----------------------------------------------------------------------

  (define qt-widget-create
    (case-lambda
      [() (ffi-qt-widget-create 0)]
      [(parent) (ffi-qt-widget-create (or parent 0))]))

  (define (qt-widget-show! w) (ffi-qt-widget-show w))
  (define (qt-widget-hide! w) (ffi-qt-widget-hide w))
  (define (qt-widget-close! w) (ffi-qt-widget-close w))

  (define (qt-widget-set-enabled! w enabled)
    (ffi-qt-widget-set-enabled w (if enabled 1 0)))
  (define (qt-widget-enabled? w)
    (not (zero? (ffi-qt-widget-is-enabled w))))

  (define (qt-widget-set-visible! w visible)
    (ffi-qt-widget-set-visible w (if visible 1 0)))
  (define (qt-widget-visible? w)
    (not (zero? (ffi-qt-widget-is-visible w))))

  (define (qt-widget-set-fixed-size! w width height)
    (ffi-qt-widget-set-fixed-size w width height))
  (define (qt-widget-set-minimum-size! w width height)
    (ffi-qt-widget-set-minimum-size w width height))
  (define (qt-widget-set-maximum-size! w width height)
    (ffi-qt-widget-set-maximum-size w width height))
  (define (qt-widget-set-minimum-width! w width)
    (ffi-qt-widget-set-minimum-width w width))
  (define (qt-widget-set-minimum-height! w height)
    (ffi-qt-widget-set-minimum-height w height))
  (define (qt-widget-set-maximum-width! w width)
    (ffi-qt-widget-set-maximum-width w width))
  (define (qt-widget-set-maximum-height! w height)
    (ffi-qt-widget-set-maximum-height w height))

  (define (qt-widget-set-cursor! w shape) (ffi-qt-widget-set-cursor w shape))
  (define (qt-widget-unset-cursor! w) (ffi-qt-widget-unset-cursor w))
  (define (qt-widget-resize! w width height) (ffi-qt-widget-resize w width height))
  (define (qt-widget-set-style-sheet! w css) (ffi-qt-widget-set-style-sheet w css))
  (define (qt-widget-set-tooltip! w text) (ffi-qt-widget-set-tooltip w text))
  (define (qt-widget-set-font-size! w size) (ffi-qt-widget-set-font-size w size))

  (define (qt-widget-destroy! w)
    (qt-disconnect-all! w)
    (ffi-qt-widget-destroy w))

  ;; Window state
  (define (qt-widget-show-minimized! w) (ffi-qt-widget-show-minimized w))
  (define (qt-widget-show-maximized! w) (ffi-qt-widget-show-maximized w))
  (define (qt-widget-show-fullscreen! w) (ffi-qt-widget-show-fullscreen w))
  (define (qt-widget-show-normal! w) (ffi-qt-widget-show-normal w))
  (define (qt-widget-window-state w) (ffi-qt-widget-window-state w))
  (define (qt-widget-move! w x y) (ffi-qt-widget-move w x y))
  (define (qt-widget-x w) (ffi-qt-widget-x w))
  (define (qt-widget-y w) (ffi-qt-widget-y w))
  (define (qt-widget-width w) (ffi-qt-widget-width w))
  (define (qt-widget-height w) (ffi-qt-widget-height w))
  (define (qt-widget-set-focus! w) (ffi-qt-widget-set-focus w))

  ;; -----------------------------------------------------------------------
  ;; Main Window
  ;; -----------------------------------------------------------------------

  (define qt-main-window-create
    (case-lambda
      [() (ffi-qt-main-window-create 0)]
      [(parent) (ffi-qt-main-window-create (or parent 0))]))

  (define (qt-main-window-set-title! w title) (ffi-qt-main-window-set-title w title))
  (define (qt-main-window-set-central-widget! w child)
    (ffi-qt-main-window-set-central-widget w child))
  (define (qt-main-window-menu-bar w) (ffi-qt-main-window-menu-bar w))
  (define (qt-main-window-add-toolbar! w tb) (ffi-qt-main-window-add-toolbar w tb))
  (define (qt-main-window-set-status-bar-text! w text)
    (ffi-qt-main-window-set-status-bar-text w text))

  ;; -----------------------------------------------------------------------
  ;; Layouts
  ;; -----------------------------------------------------------------------

  (define (qt-vbox-layout-create parent) (ffi-qt-vbox-layout-create parent))
  (define (qt-hbox-layout-create parent) (ffi-qt-hbox-layout-create parent))
  (define (qt-layout-add-widget! layout widget) (ffi-qt-layout-add-widget layout widget))

  (define qt-layout-add-stretch!
    (case-lambda
      [(layout) (ffi-qt-layout-add-stretch layout 1)]
      [(layout stretch) (ffi-qt-layout-add-stretch layout stretch)]))

  (define (qt-layout-set-spacing! layout spacing) (ffi-qt-layout-set-spacing layout spacing))
  (define (qt-layout-set-margins! layout left top right bottom)
    (ffi-qt-layout-set-margins layout left top right bottom))

  ;; Grid Layout
  (define (qt-grid-layout-create parent) (ffi-qt-grid-layout-create parent))
  (define qt-grid-layout-add-widget!
    (case-lambda
      [(layout widget row col)
       (ffi-qt-grid-layout-add-widget layout widget row col 1 1)]
      [(layout widget row col row-span col-span)
       (ffi-qt-grid-layout-add-widget layout widget row col row-span col-span)]))
  (define (qt-grid-layout-set-row-stretch! layout row stretch)
    (ffi-qt-grid-layout-set-row-stretch layout row stretch))
  (define (qt-grid-layout-set-column-stretch! layout col stretch)
    (ffi-qt-grid-layout-set-column-stretch layout col stretch))
  (define (qt-grid-layout-set-row-minimum-height! layout row height)
    (ffi-qt-grid-layout-set-row-minimum-height layout row height))
  (define (qt-grid-layout-set-column-minimum-width! layout col width)
    (ffi-qt-grid-layout-set-column-minimum-width layout col width))

  ;; -----------------------------------------------------------------------
  ;; Labels
  ;; -----------------------------------------------------------------------

  (define qt-label-create
    (case-lambda
      [(text) (ffi-qt-label-create text 0)]
      [(text parent) (ffi-qt-label-create text (or parent 0))]))

  (define (qt-label-set-text! l text) (ffi-qt-label-set-text l text))
  (define (qt-label-text l) (ffi-qt-label-text l))
  (define (qt-label-set-alignment! l alignment) (ffi-qt-label-set-alignment l alignment))
  (define (qt-label-set-word-wrap! l wrap)
    (ffi-qt-label-set-word-wrap l (if wrap 1 0)))
  (define (qt-label-set-pixmap! l pixmap) (ffi-qt-label-set-pixmap l pixmap))

  ;; -----------------------------------------------------------------------
  ;; Push Button
  ;; -----------------------------------------------------------------------

  (define qt-push-button-create
    (case-lambda
      [(text) (ffi-qt-push-button-create text 0)]
      [(text parent) (ffi-qt-push-button-create text (or parent 0))]))

  (define (qt-push-button-set-text! b text) (ffi-qt-push-button-set-text b text))
  (define (qt-push-button-text b) (ffi-qt-push-button-text b))
  (define (qt-push-button-set-icon! b icon) (ffi-qt-push-button-set-icon b icon))

  (define (qt-on-clicked! button handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-push-button-on-clicked button id)
      (track-handler! button id)))

  ;; -----------------------------------------------------------------------
  ;; Line Edit
  ;; -----------------------------------------------------------------------

  (define qt-line-edit-create
    (case-lambda
      [() (ffi-qt-line-edit-create 0)]
      [(parent) (ffi-qt-line-edit-create (or parent 0))]))

  (define (qt-line-edit-text e) (ffi-qt-line-edit-text e))
  (define (qt-line-edit-set-text! e text) (ffi-qt-line-edit-set-text e text))
  (define (qt-line-edit-set-placeholder! e text) (ffi-qt-line-edit-set-placeholder e text))
  (define (qt-line-edit-set-read-only! e ro)
    (ffi-qt-line-edit-set-read-only e (if ro 1 0)))
  (define (qt-line-edit-set-echo-mode! e mode) (ffi-qt-line-edit-set-echo-mode e mode))

  (define (qt-on-text-changed! e handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-line-edit-on-text-changed e id)
      (track-handler! e id)))

  (define (qt-on-return-pressed! e handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-line-edit-on-return-pressed e id)
      (track-handler! e id)))

  ;; -----------------------------------------------------------------------
  ;; Check Box
  ;; -----------------------------------------------------------------------

  (define qt-check-box-create
    (case-lambda
      [(text) (ffi-qt-check-box-create text 0)]
      [(text parent) (ffi-qt-check-box-create text (or parent 0))]))

  (define (qt-check-box-set-text! c text) (ffi-qt-check-box-set-text c text))
  (define (qt-check-box-set-checked! c checked)
    (ffi-qt-check-box-set-checked c (if checked 1 0)))
  (define (qt-check-box-checked? c)
    (not (zero? (ffi-qt-check-box-is-checked c))))

  (define (qt-on-toggled! c handler)
    (let ([id (register-bool-handler! handler)])
      (ffi-qt-check-box-on-toggled c id)
      (track-handler! c id)))

  ;; -----------------------------------------------------------------------
  ;; Combo Box
  ;; -----------------------------------------------------------------------

  (define qt-combo-box-create
    (case-lambda
      [() (ffi-qt-combo-box-create 0)]
      [(parent) (ffi-qt-combo-box-create (or parent 0))]))

  (define (qt-combo-box-add-item! c text) (ffi-qt-combo-box-add-item c text))
  (define (qt-combo-box-set-current-index! c idx) (ffi-qt-combo-box-set-current-index c idx))
  (define (qt-combo-box-current-index c) (ffi-qt-combo-box-current-index c))
  (define (qt-combo-box-current-text c) (ffi-qt-combo-box-current-text c))
  (define (qt-combo-box-count c) (ffi-qt-combo-box-count c))
  (define (qt-combo-box-clear! c) (ffi-qt-combo-box-clear c))

  (define (qt-on-index-changed! c handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-combo-box-on-current-index-changed c id)
      (track-handler! c id)))

  ;; -----------------------------------------------------------------------
  ;; Text Edit
  ;; -----------------------------------------------------------------------

  (define qt-text-edit-create
    (case-lambda
      [() (ffi-qt-text-edit-create 0)]
      [(parent) (ffi-qt-text-edit-create (or parent 0))]))

  (define (qt-text-edit-text e) (ffi-qt-text-edit-text e))
  (define (qt-text-edit-set-text! e text) (ffi-qt-text-edit-set-text e text))
  (define (qt-text-edit-set-placeholder! e text) (ffi-qt-text-edit-set-placeholder e text))
  (define (qt-text-edit-set-read-only! e ro)
    (ffi-qt-text-edit-set-read-only e (if ro 1 0)))
  (define (qt-text-edit-append! e text) (ffi-qt-text-edit-append e text))
  (define (qt-text-edit-clear! e) (ffi-qt-text-edit-clear e))
  (define (qt-text-edit-scroll-to-bottom! e) (ffi-qt-text-edit-scroll-to-bottom e))
  (define (qt-text-edit-html e) (ffi-qt-text-edit-html e))

  (define (qt-on-text-edit-changed! e handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-text-edit-on-text-changed e id)
      (track-handler! e id)))

  ;; -----------------------------------------------------------------------
  ;; Spin Box
  ;; -----------------------------------------------------------------------

  (define qt-spin-box-create
    (case-lambda
      [() (ffi-qt-spin-box-create 0)]
      [(parent) (ffi-qt-spin-box-create (or parent 0))]))

  (define (qt-spin-box-value s) (ffi-qt-spin-box-value s))
  (define (qt-spin-box-set-value! s val) (ffi-qt-spin-box-set-value s val))
  (define (qt-spin-box-set-range! s min max) (ffi-qt-spin-box-set-range s min max))
  (define (qt-spin-box-set-single-step! s step) (ffi-qt-spin-box-set-single-step s step))
  (define (qt-spin-box-set-prefix! s prefix) (ffi-qt-spin-box-set-prefix s prefix))
  (define (qt-spin-box-set-suffix! s suffix) (ffi-qt-spin-box-set-suffix s suffix))

  (define (qt-on-value-changed! s handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-spin-box-on-value-changed s id)
      (track-handler! s id)))

  ;; -----------------------------------------------------------------------
  ;; Dialog
  ;; -----------------------------------------------------------------------

  (define qt-dialog-create
    (case-lambda
      [() (ffi-qt-dialog-create 0)]
      [(parent) (ffi-qt-dialog-create (or parent 0))]))

  (define (qt-dialog-exec! d) (ffi-qt-dialog-exec d))
  (define (qt-dialog-accept! d) (ffi-qt-dialog-accept d))
  (define (qt-dialog-reject! d) (ffi-qt-dialog-reject d))
  (define (qt-dialog-set-title! d title) (ffi-qt-dialog-set-title d title))

  ;; -----------------------------------------------------------------------
  ;; Message Box
  ;; -----------------------------------------------------------------------

  (define qt-message-box-information
    (case-lambda
      [(title text) (ffi-qt-message-box-information 0 title text)]
      [(parent title text) (ffi-qt-message-box-information (or parent 0) title text)]))

  (define qt-message-box-warning
    (case-lambda
      [(title text) (ffi-qt-message-box-warning 0 title text)]
      [(parent title text) (ffi-qt-message-box-warning (or parent 0) title text)]))

  (define qt-message-box-question
    (case-lambda
      [(title text) (ffi-qt-message-box-question 0 title text)]
      [(parent title text) (ffi-qt-message-box-question (or parent 0) title text)]))

  (define qt-message-box-critical
    (case-lambda
      [(title text) (ffi-qt-message-box-critical 0 title text)]
      [(parent title text) (ffi-qt-message-box-critical (or parent 0) title text)]))

  ;; -----------------------------------------------------------------------
  ;; File Dialog
  ;; -----------------------------------------------------------------------

  (define qt-file-dialog-open-file
    (case-lambda
      [(caption dir filter)
       (ffi-qt-file-dialog-open-file 0 caption dir filter)]
      [(parent caption dir filter)
       (ffi-qt-file-dialog-open-file (or parent 0) caption dir filter)]))

  (define qt-file-dialog-save-file
    (case-lambda
      [(caption dir filter)
       (ffi-qt-file-dialog-save-file 0 caption dir filter)]
      [(parent caption dir filter)
       (ffi-qt-file-dialog-save-file (or parent 0) caption dir filter)]))

  (define qt-file-dialog-open-directory
    (case-lambda
      [(caption dir) (ffi-qt-file-dialog-open-directory 0 caption dir)]
      [(parent caption dir)
       (ffi-qt-file-dialog-open-directory (or parent 0) caption dir)]))

  ;; -----------------------------------------------------------------------
  ;; Menu
  ;; -----------------------------------------------------------------------

  (define (qt-menu-bar-add-menu bar title) (ffi-qt-menu-bar-add-menu bar title))
  (define (qt-menu-add-menu menu title) (ffi-qt-menu-add-menu menu title))
  (define (qt-menu-add-action! menu action) (ffi-qt-menu-add-action menu action))
  (define (qt-menu-add-separator! menu) (ffi-qt-menu-add-separator menu))

  ;; -----------------------------------------------------------------------
  ;; Action
  ;; -----------------------------------------------------------------------

  (define qt-action-create
    (case-lambda
      [(text) (ffi-qt-action-create text 0)]
      [(text parent) (ffi-qt-action-create text (or parent 0))]))

  (define (qt-action-text a) (ffi-qt-action-text a))
  (define (qt-action-set-text! a text) (ffi-qt-action-set-text a text))
  (define (qt-action-set-shortcut! a shortcut) (ffi-qt-action-set-shortcut a shortcut))
  (define (qt-action-set-enabled! a enabled)
    (ffi-qt-action-set-enabled a (if enabled 1 0)))
  (define (qt-action-enabled? a) (not (zero? (ffi-qt-action-is-enabled a))))
  (define (qt-action-set-checkable! a checkable)
    (ffi-qt-action-set-checkable a (if checkable 1 0)))
  (define (qt-action-checkable? a) (not (zero? (ffi-qt-action-is-checkable a))))
  (define (qt-action-set-checked! a checked)
    (ffi-qt-action-set-checked a (if checked 1 0)))
  (define (qt-action-checked? a) (not (zero? (ffi-qt-action-is-checked a))))
  (define (qt-action-set-tooltip! a text) (ffi-qt-action-set-tooltip a text))
  (define (qt-action-set-status-tip! a text) (ffi-qt-action-set-status-tip a text))
  (define (qt-action-set-icon! a icon) (ffi-qt-action-set-icon a icon))

  (define (qt-on-triggered! a handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-action-on-triggered a id)
      (track-handler! a id)))

  (define (qt-on-action-toggled! a handler)
    (let ([id (register-bool-handler! handler)])
      (ffi-qt-action-on-toggled a id)
      (track-handler! a id)))

  ;; -----------------------------------------------------------------------
  ;; Toolbar
  ;; -----------------------------------------------------------------------

  (define qt-toolbar-create
    (case-lambda
      [(title) (ffi-qt-toolbar-create title 0)]
      [(title parent) (ffi-qt-toolbar-create title (or parent 0))]))

  (define (qt-toolbar-add-action! tb action) (ffi-qt-toolbar-add-action tb action))
  (define (qt-toolbar-add-separator! tb) (ffi-qt-toolbar-add-separator tb))
  (define (qt-toolbar-add-widget! tb w) (ffi-qt-toolbar-add-widget tb w))
  (define (qt-toolbar-set-movable! tb movable)
    (ffi-qt-toolbar-set-movable tb (if movable 1 0)))
  (define (qt-toolbar-set-icon-size! tb w h) (ffi-qt-toolbar-set-icon-size tb w h))

  ;; -----------------------------------------------------------------------
  ;; Timer
  ;; -----------------------------------------------------------------------

  (define (qt-timer-create) (ffi-qt-timer-create))
  (define (qt-timer-start! t msec) (ffi-qt-timer-start t msec))
  (define (qt-timer-stop! t) (ffi-qt-timer-stop t))
  (define (qt-timer-set-single-shot! t ss)
    (ffi-qt-timer-set-single-shot t (if ss 1 0)))
  (define (qt-timer-active? t) (not (zero? (ffi-qt-timer-is-active t))))
  (define (qt-timer-interval t) (ffi-qt-timer-interval t))
  (define (qt-timer-set-interval! t msec) (ffi-qt-timer-set-interval t msec))
  (define (qt-timer-destroy! t) (ffi-qt-timer-destroy t))

  (define (qt-on-timeout! t handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-timer-on-timeout t id)
      (track-handler! t id)))

  (define (qt-timer-single-shot! msec handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-timer-single-shot msec id)
      id))

  ;; -----------------------------------------------------------------------
  ;; Clipboard
  ;; -----------------------------------------------------------------------

  (define (qt-clipboard-text app) (ffi-qt-clipboard-text app))
  (define (qt-clipboard-set-text! app text) (ffi-qt-clipboard-set-text app text))
  (define (qt-on-clipboard-changed! app handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-clipboard-on-changed app id)
      (track-handler! app id)))

  ;; -----------------------------------------------------------------------
  ;; Tree Widget
  ;; -----------------------------------------------------------------------

  (define qt-tree-widget-create
    (case-lambda
      [() (ffi-qt-tree-widget-create 0)]
      [(parent) (ffi-qt-tree-widget-create (or parent 0))]))

  (define (qt-tree-widget-set-column-count! t n) (ffi-qt-tree-widget-set-column-count t n))
  (define (qt-tree-widget-column-count t) (ffi-qt-tree-widget-column-count t))
  (define (qt-tree-widget-set-header-label! t label)
    (ffi-qt-tree-widget-set-header-label t label))
  (define (qt-tree-widget-set-header-item-text! t col text)
    (ffi-qt-tree-widget-set-header-item-text t col text))
  (define (qt-tree-widget-add-top-level-item! t item)
    (ffi-qt-tree-widget-add-top-level-item t item))
  (define (qt-tree-widget-top-level-item-count t)
    (ffi-qt-tree-widget-top-level-item-count t))
  (define (qt-tree-widget-top-level-item t idx)
    (ffi-qt-tree-widget-top-level-item t idx))
  (define (qt-tree-widget-current-item t) (ffi-qt-tree-widget-current-item t))
  (define (qt-tree-widget-set-current-item! t item)
    (ffi-qt-tree-widget-set-current-item t item))
  (define (qt-tree-widget-expand-item! t item) (ffi-qt-tree-widget-expand-item t item))
  (define (qt-tree-widget-collapse-item! t item) (ffi-qt-tree-widget-collapse-item t item))
  (define (qt-tree-widget-expand-all! t) (ffi-qt-tree-widget-expand-all t))
  (define (qt-tree-widget-collapse-all! t) (ffi-qt-tree-widget-collapse-all t))
  (define (qt-tree-widget-clear! t) (ffi-qt-tree-widget-clear t))

  (define (qt-on-current-item-changed! t handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-tree-widget-on-current-item-changed t id)
      (track-handler! t id)))
  (define (qt-on-tree-item-double-clicked! t handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-tree-widget-on-item-double-clicked t id)
      (track-handler! t id)))
  (define (qt-on-item-expanded! t handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-tree-widget-on-item-expanded t id)
      (track-handler! t id)))
  (define (qt-on-item-collapsed! t handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-tree-widget-on-item-collapsed t id)
      (track-handler! t id)))

  ;; Tree Widget Item
  (define (qt-tree-item-create text) (ffi-qt-tree-item-create text))
  (define (qt-tree-item-set-text! item col text) (ffi-qt-tree-item-set-text item col text))
  (define (qt-tree-item-text item col) (ffi-qt-tree-item-text item col))
  (define (qt-tree-item-add-child! item child) (ffi-qt-tree-item-add-child item child))
  (define (qt-tree-item-child-count item) (ffi-qt-tree-item-child-count item))
  (define (qt-tree-item-child item idx) (ffi-qt-tree-item-child item idx))
  (define (qt-tree-item-parent item) (ffi-qt-tree-item-parent item))
  (define (qt-tree-item-set-expanded! item expanded)
    (ffi-qt-tree-item-set-expanded item (if expanded 1 0)))
  (define (qt-tree-item-expanded? item)
    (not (zero? (ffi-qt-tree-item-is-expanded item))))

  ;; -----------------------------------------------------------------------
  ;; List Widget
  ;; -----------------------------------------------------------------------

  (define qt-list-widget-create
    (case-lambda
      [() (ffi-qt-list-widget-create 0)]
      [(parent) (ffi-qt-list-widget-create (or parent 0))]))

  (define (qt-list-widget-add-item! l text) (ffi-qt-list-widget-add-item l text))
  (define (qt-list-widget-insert-item! l row text) (ffi-qt-list-widget-insert-item l row text))
  (define (qt-list-widget-remove-item! l row) (ffi-qt-list-widget-remove-item l row))
  (define (qt-list-widget-current-row l) (ffi-qt-list-widget-current-row l))
  (define (qt-list-widget-set-current-row! l row) (ffi-qt-list-widget-set-current-row l row))
  (define (qt-list-widget-item-text l row) (ffi-qt-list-widget-item-text l row))
  (define (qt-list-widget-count l) (ffi-qt-list-widget-count l))
  (define (qt-list-widget-clear! l) (ffi-qt-list-widget-clear l))
  (define (qt-list-widget-set-item-data! l row data)
    (ffi-qt-list-widget-set-item-data l row data))
  (define (qt-list-widget-item-data l row) (ffi-qt-list-widget-item-data l row))

  (define (qt-on-current-row-changed! l handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-list-widget-on-current-row-changed l id)
      (track-handler! l id)))
  (define (qt-on-item-double-clicked! l handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-list-widget-on-item-double-clicked l id)
      (track-handler! l id)))

  ;; -----------------------------------------------------------------------
  ;; Table Widget
  ;; -----------------------------------------------------------------------

  (define qt-table-widget-create
    (case-lambda
      [(rows cols) (ffi-qt-table-widget-create rows cols 0)]
      [(rows cols parent) (ffi-qt-table-widget-create rows cols (or parent 0))]))

  (define (qt-table-widget-set-item! t row col text)
    (ffi-qt-table-widget-set-item t row col text))
  (define (qt-table-widget-item-text t row col)
    (ffi-qt-table-widget-item-text t row col))
  (define (qt-table-widget-set-horizontal-header! t col text)
    (ffi-qt-table-widget-set-horizontal-header-item t col text))
  (define (qt-table-widget-set-vertical-header! t row text)
    (ffi-qt-table-widget-set-vertical-header-item t row text))
  (define (qt-table-widget-set-row-count! t n) (ffi-qt-table-widget-set-row-count t n))
  (define (qt-table-widget-set-column-count! t n) (ffi-qt-table-widget-set-column-count t n))
  (define (qt-table-widget-row-count t) (ffi-qt-table-widget-row-count t))
  (define (qt-table-widget-column-count t) (ffi-qt-table-widget-column-count t))
  (define (qt-table-widget-current-row t) (ffi-qt-table-widget-current-row t))
  (define (qt-table-widget-current-column t) (ffi-qt-table-widget-current-column t))
  (define (qt-table-widget-clear! t) (ffi-qt-table-widget-clear t))

  (define (qt-on-cell-clicked! t handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-table-widget-on-cell-clicked t id)
      (track-handler! t id)))

  ;; -----------------------------------------------------------------------
  ;; Tab Widget
  ;; -----------------------------------------------------------------------

  (define qt-tab-widget-create
    (case-lambda
      [() (ffi-qt-tab-widget-create 0)]
      [(parent) (ffi-qt-tab-widget-create (or parent 0))]))

  (define (qt-tab-widget-add-tab! tw widget label) (ffi-qt-tab-widget-add-tab tw widget label))
  (define (qt-tab-widget-set-current-index! tw idx) (ffi-qt-tab-widget-set-current-index tw idx))
  (define (qt-tab-widget-current-index tw) (ffi-qt-tab-widget-current-index tw))
  (define (qt-tab-widget-count tw) (ffi-qt-tab-widget-count tw))
  (define (qt-tab-widget-set-tab-text! tw idx text) (ffi-qt-tab-widget-set-tab-text tw idx text))

  (define (qt-on-tab-changed! tw handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-tab-widget-on-current-changed tw id)
      (track-handler! tw id)))

  ;; -----------------------------------------------------------------------
  ;; Progress Bar
  ;; -----------------------------------------------------------------------

  (define qt-progress-bar-create
    (case-lambda
      [() (ffi-qt-progress-bar-create 0)]
      [(parent) (ffi-qt-progress-bar-create (or parent 0))]))

  (define (qt-progress-bar-set-value! p val) (ffi-qt-progress-bar-set-value p val))
  (define (qt-progress-bar-value p) (ffi-qt-progress-bar-value p))
  (define (qt-progress-bar-set-range! p min max) (ffi-qt-progress-bar-set-range p min max))
  (define (qt-progress-bar-set-format! p fmt) (ffi-qt-progress-bar-set-format p fmt))

  ;; -----------------------------------------------------------------------
  ;; Slider
  ;; -----------------------------------------------------------------------

  (define qt-slider-create
    (case-lambda
      [(orientation) (ffi-qt-slider-create orientation 0)]
      [(orientation parent) (ffi-qt-slider-create orientation (or parent 0))]))

  (define (qt-slider-set-value! s val) (ffi-qt-slider-set-value s val))
  (define (qt-slider-value s) (ffi-qt-slider-value s))
  (define (qt-slider-set-range! s min max) (ffi-qt-slider-set-range s min max))
  (define (qt-slider-set-single-step! s step) (ffi-qt-slider-set-single-step s step))
  (define (qt-slider-set-tick-interval! s interval) (ffi-qt-slider-set-tick-interval s interval))
  (define (qt-slider-set-tick-position! s pos) (ffi-qt-slider-set-tick-position s pos))

  (define (qt-on-slider-value-changed! s handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-slider-on-value-changed s id)
      (track-handler! s id)))

  ;; -----------------------------------------------------------------------
  ;; App-wide Style Sheet
  ;; -----------------------------------------------------------------------

  (define (qt-app-set-style-sheet! app css) (ffi-qt-app-set-style-sheet app css))

  ;; -----------------------------------------------------------------------
  ;; Scroll Area
  ;; -----------------------------------------------------------------------

  (define qt-scroll-area-create
    (case-lambda
      [() (ffi-qt-scroll-area-create 0)]
      [(parent) (ffi-qt-scroll-area-create (or parent 0))]))

  (define (qt-scroll-area-set-widget! sa w) (ffi-qt-scroll-area-set-widget sa w))
  (define (qt-scroll-area-set-widget-resizable! sa resizable)
    (ffi-qt-scroll-area-set-widget-resizable sa (if resizable 1 0)))
  (define (qt-scroll-area-set-horizontal-scrollbar-policy! sa policy)
    (ffi-qt-scroll-area-set-horizontal-scrollbar-policy sa policy))
  (define (qt-scroll-area-set-vertical-scrollbar-policy! sa policy)
    (ffi-qt-scroll-area-set-vertical-scrollbar-policy sa policy))

  ;; -----------------------------------------------------------------------
  ;; Splitter
  ;; -----------------------------------------------------------------------

  (define qt-splitter-create
    (case-lambda
      [(orientation) (ffi-qt-splitter-create orientation 0)]
      [(orientation parent) (ffi-qt-splitter-create orientation (or parent 0))]))

  (define (qt-splitter-add-widget! s w) (ffi-qt-splitter-add-widget s w))
  (define (qt-splitter-insert-widget! s idx w) (ffi-qt-splitter-insert-widget s idx w))
  (define (qt-splitter-index-of s w) (ffi-qt-splitter-index-of s w))
  (define (qt-splitter-widget s idx) (ffi-qt-splitter-widget s idx))
  (define (qt-splitter-count s) (ffi-qt-splitter-count s))
  (define qt-splitter-set-sizes!
    (case-lambda
      [(s sizes)
       ;; Accept a list of sizes and dispatch to the appropriate FFI call
       (cond
         [(and (pair? sizes) (= (length sizes) 2))
          (ffi-qt-splitter-set-sizes-2 s (car sizes) (cadr sizes))]
         [(and (pair? sizes) (= (length sizes) 3))
          (ffi-qt-splitter-set-sizes-3 s (car sizes) (cadr sizes) (caddr sizes))]
         [(and (pair? sizes) (= (length sizes) 4))
          (ffi-qt-splitter-set-sizes-4 s (car sizes) (cadr sizes) (caddr sizes) (cadddr sizes))]
         [(and (pair? sizes) (> (length sizes) 4))
          ;; For 5+ children, use stretch factors for equal sizing
          (let ((n (length sizes)))
            (do ((i 0 (+ i 1)))
                ((= i n))
              (ffi-qt-splitter-set-stretch-factor s i 1)))]
         [else (void)])]
      [(s a b)     (ffi-qt-splitter-set-sizes-2 s a b)]
      [(s a b c)   (ffi-qt-splitter-set-sizes-3 s a b c)]
      [(s a b c d) (ffi-qt-splitter-set-sizes-4 s a b c d)]))
  (define (qt-splitter-size-at s idx) (ffi-qt-splitter-size-at s idx))
  (define (qt-splitter-set-stretch-factor! s idx factor)
    (ffi-qt-splitter-set-stretch-factor s idx factor))
  (define (qt-splitter-set-handle-width! s w) (ffi-qt-splitter-set-handle-width s w))
  (define (qt-splitter-set-collapsible! s idx collapsible)
    (ffi-qt-splitter-set-collapsible s idx (if collapsible 1 0)))
  (define (qt-splitter-collapsible? s idx)
    (not (zero? (ffi-qt-splitter-is-collapsible s idx))))
  (define (qt-splitter-set-orientation! s orientation)
    (ffi-qt-splitter-set-orientation s orientation))

  ;; -----------------------------------------------------------------------
  ;; Keyboard Events
  ;; -----------------------------------------------------------------------

  (define (qt-on-key-press! w handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-install-key-handler w id)
      (track-handler! w id)))

  (define (qt-on-key-press-consuming! w handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-install-key-handler-consuming w id)
      (track-handler! w id)))

  (define (qt-last-key-code) (ffi-qt-last-key-code))
  (define (qt-last-key-modifiers) (ffi-qt-last-key-modifiers))
  (define (qt-last-key-text) (ffi-qt-last-key-text))

  ;; -----------------------------------------------------------------------
  ;; Pixmap
  ;; -----------------------------------------------------------------------

  (define (qt-pixmap-load path) (ffi-qt-pixmap-load path))
  (define (qt-pixmap-width p) (ffi-qt-pixmap-width p))
  (define (qt-pixmap-height p) (ffi-qt-pixmap-height p))
  (define (qt-pixmap-null? p) (not (zero? (ffi-qt-pixmap-is-null p))))
  (define (qt-pixmap-scaled p w h mode) (ffi-qt-pixmap-scaled p w h mode))
  (define (qt-pixmap-destroy! p) (ffi-qt-pixmap-destroy p))

  ;; -----------------------------------------------------------------------
  ;; Icon
  ;; -----------------------------------------------------------------------

  (define (qt-icon-create path) (ffi-qt-icon-create path))
  (define (qt-icon-create-from-pixmap p) (ffi-qt-icon-create-from-pixmap p))
  (define (qt-icon-null? i) (not (zero? (ffi-qt-icon-is-null i))))
  (define (qt-icon-destroy! i) (ffi-qt-icon-destroy i))
  (define (qt-widget-set-window-icon! w i) (ffi-qt-widget-set-window-icon w i))

  ;; -----------------------------------------------------------------------
  ;; Radio Button
  ;; -----------------------------------------------------------------------

  (define qt-radio-button-create
    (case-lambda
      [(text) (ffi-qt-radio-button-create text 0)]
      [(text parent) (ffi-qt-radio-button-create text (or parent 0))]))

  (define (qt-radio-button-text r) (ffi-qt-radio-button-text r))
  (define (qt-radio-button-set-text! r text) (ffi-qt-radio-button-set-text r text))
  (define (qt-radio-button-checked? r) (not (zero? (ffi-qt-radio-button-is-checked r))))
  (define (qt-radio-button-set-checked! r checked)
    (ffi-qt-radio-button-set-checked r (if checked 1 0)))

  (define (qt-on-radio-toggled! r handler)
    (let ([id (register-bool-handler! handler)])
      (ffi-qt-radio-button-on-toggled r id)
      (track-handler! r id)))

  ;; -----------------------------------------------------------------------
  ;; Button Group
  ;; -----------------------------------------------------------------------

  (define qt-button-group-create
    (case-lambda
      [() (ffi-qt-button-group-create 0)]
      [(parent) (ffi-qt-button-group-create (or parent 0))]))

  (define (qt-button-group-add-button! g button id)
    (ffi-qt-button-group-add-button g button id))
  (define (qt-button-group-remove-button! g button)
    (ffi-qt-button-group-remove-button g button))
  (define (qt-button-group-checked-id g) (ffi-qt-button-group-checked-id g))
  (define (qt-button-group-set-exclusive! g exclusive)
    (ffi-qt-button-group-set-exclusive g (if exclusive 1 0)))
  (define (qt-button-group-exclusive? g)
    (not (zero? (ffi-qt-button-group-is-exclusive g))))
  (define (qt-button-group-destroy! g) (ffi-qt-button-group-destroy g))

  (define (qt-on-button-group-clicked! g handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-button-group-on-clicked g id)
      (track-handler! g id)))

  ;; -----------------------------------------------------------------------
  ;; Group Box
  ;; -----------------------------------------------------------------------

  (define qt-group-box-create
    (case-lambda
      [(title) (ffi-qt-group-box-create title 0)]
      [(title parent) (ffi-qt-group-box-create title (or parent 0))]))

  (define (qt-group-box-title g) (ffi-qt-group-box-title g))
  (define (qt-group-box-set-title! g title) (ffi-qt-group-box-set-title g title))
  (define (qt-group-box-set-checkable! g checkable)
    (ffi-qt-group-box-set-checkable g (if checkable 1 0)))
  (define (qt-group-box-checkable? g) (not (zero? (ffi-qt-group-box-is-checkable g))))
  (define (qt-group-box-set-checked! g checked)
    (ffi-qt-group-box-set-checked g (if checked 1 0)))
  (define (qt-group-box-checked? g) (not (zero? (ffi-qt-group-box-is-checked g))))

  (define (qt-on-group-box-toggled! g handler)
    (let ([id (register-bool-handler! handler)])
      (ffi-qt-group-box-on-toggled g id)
      (track-handler! g id)))

  ;; -----------------------------------------------------------------------
  ;; Font
  ;; -----------------------------------------------------------------------

  (define (qt-font-create family size) (ffi-qt-font-create family size))
  (define (qt-font-family f) (ffi-qt-font-family f))
  (define (qt-font-point-size f) (ffi-qt-font-point-size f))
  (define (qt-font-bold? f) (not (zero? (ffi-qt-font-is-bold f))))
  (define (qt-font-set-bold! f bold) (ffi-qt-font-set-bold f (if bold 1 0)))
  (define (qt-font-italic? f) (not (zero? (ffi-qt-font-is-italic f))))
  (define (qt-font-set-italic! f italic) (ffi-qt-font-set-italic f (if italic 1 0)))
  (define (qt-font-destroy! f) (ffi-qt-font-destroy f))
  (define (qt-widget-set-font! w f) (ffi-qt-widget-set-font w f))
  (define (qt-widget-font w) (ffi-qt-widget-font w))

  ;; -----------------------------------------------------------------------
  ;; Color
  ;; -----------------------------------------------------------------------

  (define qt-color-create
    (case-lambda
      [(r g b) (ffi-qt-color-create r g b 255)]
      [(r g b a) (ffi-qt-color-create r g b a)]))

  (define (qt-color-create-name name) (ffi-qt-color-create-name name))
  (define (qt-color-red c) (ffi-qt-color-red c))
  (define (qt-color-green c) (ffi-qt-color-green c))
  (define (qt-color-blue c) (ffi-qt-color-blue c))
  (define (qt-color-alpha c) (ffi-qt-color-alpha c))
  (define (qt-color-name c) (ffi-qt-color-name c))
  (define (qt-color-valid? c) (not (zero? (ffi-qt-color-is-valid c))))
  (define (qt-color-destroy! c) (ffi-qt-color-destroy c))

  ;; -----------------------------------------------------------------------
  ;; Font Dialog / Color Dialog
  ;; -----------------------------------------------------------------------

  (define qt-font-dialog-get-font
    (case-lambda
      [() (ffi-qt-font-dialog-get-font 0)]
      [(parent) (ffi-qt-font-dialog-get-font (or parent 0))]))

  (define qt-color-dialog-get-color
    (case-lambda
      [() (ffi-qt-color-dialog-get-color "" 0)]
      [(initial) (ffi-qt-color-dialog-get-color initial 0)]
      [(initial parent) (ffi-qt-color-dialog-get-color initial (or parent 0))]))

  ;; -----------------------------------------------------------------------
  ;; Stacked Widget
  ;; -----------------------------------------------------------------------

  (define qt-stacked-widget-create
    (case-lambda
      [() (ffi-qt-stacked-widget-create 0)]
      [(parent) (ffi-qt-stacked-widget-create (or parent 0))]))

  (define (qt-stacked-widget-add-widget! sw w) (ffi-qt-stacked-widget-add-widget sw w))
  (define (qt-stacked-widget-set-current-index! sw idx) (ffi-qt-stacked-widget-set-current-index sw idx))
  (define (qt-stacked-widget-current-index sw) (ffi-qt-stacked-widget-current-index sw))
  (define (qt-stacked-widget-count sw) (ffi-qt-stacked-widget-count sw))

  (define (qt-on-stacked-current-changed! sw handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-stacked-widget-on-current-changed sw id)
      (track-handler! sw id)))

  ;; -----------------------------------------------------------------------
  ;; Dock Widget
  ;; -----------------------------------------------------------------------

  (define qt-dock-widget-create
    (case-lambda
      [(title) (ffi-qt-dock-widget-create title 0)]
      [(title parent) (ffi-qt-dock-widget-create title (or parent 0))]))

  (define (qt-dock-widget-set-widget! dw w) (ffi-qt-dock-widget-set-widget dw w))
  (define (qt-dock-widget-widget dw) (ffi-qt-dock-widget-widget dw))
  (define (qt-dock-widget-set-title! dw title) (ffi-qt-dock-widget-set-title dw title))
  (define (qt-dock-widget-title dw) (ffi-qt-dock-widget-title dw))
  (define (qt-dock-widget-set-floating! dw floating)
    (ffi-qt-dock-widget-set-floating dw (if floating 1 0)))
  (define (qt-dock-widget-floating? dw) (not (zero? (ffi-qt-dock-widget-is-floating dw))))
  (define (qt-main-window-add-dock-widget! mw area dw)
    (ffi-qt-main-window-add-dock-widget mw area dw))

  ;; -----------------------------------------------------------------------
  ;; System Tray Icon
  ;; -----------------------------------------------------------------------

  (define qt-system-tray-icon-create
    (case-lambda
      [(icon) (ffi-qt-system-tray-icon-create icon 0)]
      [(icon parent) (ffi-qt-system-tray-icon-create icon (or parent 0))]))

  (define (qt-system-tray-icon-set-tooltip! ti text) (ffi-qt-system-tray-icon-set-tooltip ti text))
  (define (qt-system-tray-icon-set-icon! ti icon) (ffi-qt-system-tray-icon-set-icon ti icon))
  (define (qt-system-tray-icon-show! ti) (ffi-qt-system-tray-icon-show ti))
  (define (qt-system-tray-icon-hide! ti) (ffi-qt-system-tray-icon-hide ti))

  (define qt-system-tray-icon-show-message!
    (case-lambda
      [(ti title msg) (ffi-qt-system-tray-icon-show-message ti title msg 1 5000)]
      [(ti title msg icon-type) (ffi-qt-system-tray-icon-show-message ti title msg icon-type 5000)]
      [(ti title msg icon-type msecs) (ffi-qt-system-tray-icon-show-message ti title msg icon-type msecs)]))

  (define (qt-system-tray-icon-set-context-menu! ti menu)
    (ffi-qt-system-tray-icon-set-context-menu ti menu))

  (define (qt-on-tray-activated! ti handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-system-tray-icon-on-activated ti id)
      (track-handler! ti id)))

  (define (qt-system-tray-icon-available?) (not (zero? (ffi-qt-system-tray-icon-is-available))))
  (define (qt-system-tray-icon-destroy! ti) (ffi-qt-system-tray-icon-destroy ti))

  ;; -----------------------------------------------------------------------
  ;; QPainter
  ;; -----------------------------------------------------------------------

  (define (qt-pixmap-create-blank w h) (ffi-qt-pixmap-create-blank w h))
  (define (qt-pixmap-fill! pm r g b a) (ffi-qt-pixmap-fill pm r g b a))

  (define (qt-painter-create target) (ffi-qt-painter-create target))
  (define (qt-painter-end! p) (ffi-qt-painter-end p))
  (define (qt-painter-destroy! p) (ffi-qt-painter-destroy p))

  (define qt-painter-set-pen-color!
    (case-lambda
      [(p r g b) (ffi-qt-painter-set-pen-color p r g b 255)]
      [(p r g b a) (ffi-qt-painter-set-pen-color p r g b a)]))

  (define (qt-painter-set-pen-width! p w) (ffi-qt-painter-set-pen-width p w))

  (define qt-painter-set-brush-color!
    (case-lambda
      [(p r g b) (ffi-qt-painter-set-brush-color p r g b 255)]
      [(p r g b a) (ffi-qt-painter-set-brush-color p r g b a)]))

  (define (qt-painter-set-font! p f) (ffi-qt-painter-set-font-painter p f))
  (define (qt-painter-set-antialiasing! p enabled)
    (ffi-qt-painter-set-antialiasing p (if enabled 1 0)))

  (define (qt-painter-draw-line! p x1 y1 x2 y2)
    (ffi-qt-painter-draw-line p x1 y1 x2 y2))
  (define (qt-painter-draw-rect! p x y w h)
    (ffi-qt-painter-draw-rect p x y w h))
  (define (qt-painter-fill-rect! p x y w h r g b a)
    (ffi-qt-painter-fill-rect p x y w h r g b a))
  (define (qt-painter-draw-ellipse! p x y w h)
    (ffi-qt-painter-draw-ellipse p x y w h))
  (define (qt-painter-draw-text! p x y text)
    (ffi-qt-painter-draw-text p x y text))
  (define (qt-painter-draw-text-rect! p x y w h flags text)
    (ffi-qt-painter-draw-text-rect p x y w h flags text))
  (define (qt-painter-draw-pixmap! p x y pm)
    (ffi-qt-painter-draw-pixmap p x y pm))
  (define (qt-painter-draw-point! p x y)
    (ffi-qt-painter-draw-point p x y))
  (define (qt-painter-draw-arc! p x y w h start-angle span-angle)
    (ffi-qt-painter-draw-arc p x y w h start-angle span-angle))
  (define (qt-painter-save! p) (ffi-qt-painter-save p))
  (define (qt-painter-restore! p) (ffi-qt-painter-restore p))
  (define (qt-painter-translate! p dx dy) (ffi-qt-painter-translate p dx dy))
  (define (qt-painter-rotate! p angle) (ffi-qt-painter-rotate p (exact->inexact angle)))
  (define (qt-painter-scale! p sx sy)
    (ffi-qt-painter-scale p (exact->inexact sx) (exact->inexact sy)))

  (define-syntax with-painter
    (syntax-rules ()
      [(_ (p target) body ...)
       (let ([p (qt-painter-create target)])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda ()
             (qt-painter-end! p)
             (qt-painter-destroy! p))))]))

  ;; -----------------------------------------------------------------------
  ;; Drag and Drop
  ;; -----------------------------------------------------------------------

  (define (qt-widget-set-accept-drops! w accept)
    (ffi-qt-widget-set-accept-drops w (if accept 1 0)))
  (define (qt-drop-filter-install! w handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-drop-filter-install w (foreign-callable-entry-point string-trampoline) id)))
  (define (qt-drop-filter-last-text df) (ffi-qt-drop-filter-last-text df))
  (define (qt-drop-filter-destroy! df) (ffi-qt-drop-filter-destroy df))
  (define (qt-drag-text! source text) (ffi-qt-drag-text source text))

  ;; -----------------------------------------------------------------------
  ;; Double Spin Box
  ;; -----------------------------------------------------------------------

  (define qt-double-spin-box-create
    (case-lambda
      [() (ffi-qt-double-spin-box-create 0)]
      [(parent) (ffi-qt-double-spin-box-create (or parent 0))]))

  (define (qt-double-spin-box-set-value! s value)
    (ffi-qt-double-spin-box-set-value s (exact->inexact value)))
  (define (qt-double-spin-box-value s) (ffi-qt-double-spin-box-value s))
  (define (qt-double-spin-box-set-range! s min max)
    (ffi-qt-double-spin-box-set-range s (exact->inexact min) (exact->inexact max)))
  (define (qt-double-spin-box-set-single-step! s step)
    (ffi-qt-double-spin-box-set-single-step s (exact->inexact step)))
  (define (qt-double-spin-box-set-decimals! s d) (ffi-qt-double-spin-box-set-decimals s d))
  (define (qt-double-spin-box-decimals s) (ffi-qt-double-spin-box-decimals s))
  (define (qt-double-spin-box-set-prefix! s p) (ffi-qt-double-spin-box-set-prefix s p))
  (define (qt-double-spin-box-set-suffix! s p) (ffi-qt-double-spin-box-set-suffix s p))

  (define (qt-on-double-spin-value-changed! s handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-double-spin-box-on-value-changed s id)
      (track-handler! s id)))

  ;; -----------------------------------------------------------------------
  ;; Date Edit
  ;; -----------------------------------------------------------------------

  (define qt-date-edit-create
    (case-lambda
      [() (ffi-qt-date-edit-create 0)]
      [(parent) (ffi-qt-date-edit-create (or parent 0))]))

  (define (qt-date-edit-set-date! d year month day) (ffi-qt-date-edit-set-date d year month day))
  (define (qt-date-edit-year d) (ffi-qt-date-edit-year d))
  (define (qt-date-edit-month d) (ffi-qt-date-edit-month d))
  (define (qt-date-edit-day d) (ffi-qt-date-edit-day d))
  (define (qt-date-edit-date-string d) (ffi-qt-date-edit-date-string d))
  (define (qt-date-edit-set-minimum-date! d year month day)
    (ffi-qt-date-edit-set-minimum-date d year month day))
  (define (qt-date-edit-set-maximum-date! d year month day)
    (ffi-qt-date-edit-set-maximum-date d year month day))
  (define (qt-date-edit-set-calendar-popup! d enabled)
    (ffi-qt-date-edit-set-calendar-popup d (if enabled 1 0)))
  (define (qt-date-edit-set-display-format! d fmt) (ffi-qt-date-edit-set-display-format d fmt))

  (define (qt-on-date-changed! d handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-date-edit-on-date-changed d id)
      (track-handler! d id)))

  ;; -----------------------------------------------------------------------
  ;; Time Edit
  ;; -----------------------------------------------------------------------

  (define qt-time-edit-create
    (case-lambda
      [() (ffi-qt-time-edit-create 0)]
      [(parent) (ffi-qt-time-edit-create (or parent 0))]))

  (define (qt-time-edit-set-time! t hour minute second) (ffi-qt-time-edit-set-time t hour minute second))
  (define (qt-time-edit-hour t) (ffi-qt-time-edit-hour t))
  (define (qt-time-edit-minute t) (ffi-qt-time-edit-minute t))
  (define (qt-time-edit-second t) (ffi-qt-time-edit-second t))
  (define (qt-time-edit-time-string t) (ffi-qt-time-edit-time-string t))
  (define (qt-time-edit-set-display-format! t fmt) (ffi-qt-time-edit-set-display-format t fmt))

  (define (qt-on-time-changed! t handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-time-edit-on-time-changed t id)
      (track-handler! t id)))

  ;; -----------------------------------------------------------------------
  ;; Frame
  ;; -----------------------------------------------------------------------

  (define qt-frame-create
    (case-lambda
      [() (ffi-qt-frame-create 0)]
      [(parent) (ffi-qt-frame-create (or parent 0))]))

  (define (qt-frame-set-frame-shape! f shape) (ffi-qt-frame-set-frame-shape f shape))
  (define (qt-frame-frame-shape f) (ffi-qt-frame-frame-shape f))
  (define (qt-frame-set-frame-shadow! f shadow) (ffi-qt-frame-set-frame-shadow f shadow))
  (define (qt-frame-frame-shadow f) (ffi-qt-frame-frame-shadow f))
  (define (qt-frame-set-line-width! f w) (ffi-qt-frame-set-line-width f w))
  (define (qt-frame-line-width f) (ffi-qt-frame-line-width f))
  (define (qt-frame-set-mid-line-width! f w) (ffi-qt-frame-set-mid-line-width f w))

  ;; -----------------------------------------------------------------------
  ;; Progress Dialog
  ;; -----------------------------------------------------------------------

  (define qt-progress-dialog-create
    (case-lambda
      [(label cancel min max) (ffi-qt-progress-dialog-create label cancel min max 0)]
      [(label cancel min max parent) (ffi-qt-progress-dialog-create label cancel min max (or parent 0))]))

  (define (qt-progress-dialog-set-value! pd v) (ffi-qt-progress-dialog-set-value pd v))
  (define (qt-progress-dialog-value pd) (ffi-qt-progress-dialog-value pd))
  (define (qt-progress-dialog-set-range! pd min max) (ffi-qt-progress-dialog-set-range pd min max))
  (define (qt-progress-dialog-set-label-text! pd text) (ffi-qt-progress-dialog-set-label-text pd text))
  (define (qt-progress-dialog-was-canceled? pd) (not (zero? (ffi-qt-progress-dialog-was-canceled pd))))
  (define (qt-progress-dialog-set-minimum-duration! pd msecs) (ffi-qt-progress-dialog-set-minimum-duration pd msecs))
  (define (qt-progress-dialog-set-auto-close! pd enabled)
    (ffi-qt-progress-dialog-set-auto-close pd (if enabled 1 0)))
  (define (qt-progress-dialog-set-auto-reset! pd enabled)
    (ffi-qt-progress-dialog-set-auto-reset pd (if enabled 1 0)))
  (define (qt-progress-dialog-reset! pd) (ffi-qt-progress-dialog-reset pd))

  (define (qt-on-progress-canceled! pd handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-progress-dialog-on-canceled pd id)
      (track-handler! pd id)))

  ;; -----------------------------------------------------------------------
  ;; Input Dialog
  ;; -----------------------------------------------------------------------

  (define qt-input-dialog-get-text
    (case-lambda
      [(parent title label) (ffi-qt-input-dialog-get-text (or parent 0) title label "")]
      [(parent title label default) (ffi-qt-input-dialog-get-text (or parent 0) title label default)]))

  (define (qt-input-dialog-get-int parent title label value min max step)
    (ffi-qt-input-dialog-get-int (or parent 0) title label value min max step))

  (define (qt-input-dialog-get-double parent title label value min max decimals)
    (ffi-qt-input-dialog-get-double (or parent 0) title label
      (exact->inexact value) (exact->inexact min) (exact->inexact max) decimals))

  (define (qt-input-dialog-get-item parent title label items current editable)
    (let ([items-str (if (list? items) (string-join items "\n") items)])
      (ffi-qt-input-dialog-get-item (or parent 0) title label items-str current (if editable 1 0))))

  (define (qt-input-dialog-was-accepted?) (not (zero? (ffi-qt-input-dialog-was-accepted))))

  ;; Helper for string-join (not in standard Chez)
  (define (string-join strs sep)
    (if (null? strs) ""
        (let loop ([rest (cdr strs)] [acc (car strs)])
          (if (null? rest) acc
              (loop (cdr rest) (string-append acc sep (car rest)))))))

  ;; -----------------------------------------------------------------------
  ;; Form Layout
  ;; -----------------------------------------------------------------------

  (define qt-form-layout-create
    (case-lambda
      [() (ffi-qt-form-layout-create 0)]
      [(parent) (ffi-qt-form-layout-create (or parent 0))]))

  (define (qt-form-layout-add-row! layout label field) (ffi-qt-form-layout-add-row layout label field))
  (define (qt-form-layout-add-row-widget! layout label-w field) (ffi-qt-form-layout-add-row-widget layout label-w field))
  (define (qt-form-layout-add-spanning-widget! layout w) (ffi-qt-form-layout-add-spanning-widget layout w))
  (define (qt-form-layout-row-count layout) (ffi-qt-form-layout-row-count layout))

  ;; -----------------------------------------------------------------------
  ;; Shortcut
  ;; -----------------------------------------------------------------------

  (define qt-shortcut-create
    (case-lambda
      [(key parent) (ffi-qt-shortcut-create key (or parent 0))]))

  (define (qt-shortcut-set-key! s key) (ffi-qt-shortcut-set-key s key))
  (define (qt-shortcut-set-enabled! s enabled) (ffi-qt-shortcut-set-enabled s (if enabled 1 0)))
  (define (qt-shortcut-enabled? s) (not (zero? (ffi-qt-shortcut-is-enabled s))))

  (define (qt-on-shortcut-activated! s handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-shortcut-on-activated s id)
      (track-handler! s id)))

  (define (qt-shortcut-destroy! s) (ffi-qt-shortcut-destroy s))

  ;; -----------------------------------------------------------------------
  ;; Text Browser
  ;; -----------------------------------------------------------------------

  (define qt-text-browser-create
    (case-lambda
      [() (ffi-qt-text-browser-create 0)]
      [(parent) (ffi-qt-text-browser-create (or parent 0))]))

  (define (qt-text-browser-set-html! tb html) (ffi-qt-text-browser-set-html tb html))
  (define (qt-text-browser-set-plain-text! tb text) (ffi-qt-text-browser-set-plain-text tb text))
  (define (qt-text-browser-plain-text tb) (ffi-qt-text-browser-plain-text tb))
  (define (qt-text-browser-set-open-external-links! tb enabled)
    (ffi-qt-text-browser-set-open-external-links tb (if enabled 1 0)))
  (define (qt-text-browser-set-source! tb url) (ffi-qt-text-browser-set-source tb url))
  (define (qt-text-browser-source tb) (ffi-qt-text-browser-source tb))
  (define (qt-text-browser-scroll-to-bottom! tb) (ffi-qt-text-browser-scroll-to-bottom tb))
  (define (qt-text-browser-append! tb text) (ffi-qt-text-browser-append tb text))
  (define (qt-text-browser-html tb) (ffi-qt-text-browser-html tb))

  (define (qt-on-anchor-clicked! tb handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-text-browser-on-anchor-clicked tb id)
      (track-handler! tb id)))

  ;; -----------------------------------------------------------------------
  ;; Button Box
  ;; -----------------------------------------------------------------------

  (define qt-button-box-create
    (case-lambda
      [(buttons) (ffi-qt-button-box-create buttons 0)]
      [(buttons parent) (ffi-qt-button-box-create buttons (or parent 0))]))

  (define (qt-button-box-button bb standard-button) (ffi-qt-button-box-button bb standard-button))
  (define (qt-button-box-add-button! bb button role) (ffi-qt-button-box-add-button bb button role))

  (define (qt-on-button-box-accepted! bb handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-button-box-on-accepted bb id)
      (track-handler! bb id)))
  (define (qt-on-button-box-rejected! bb handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-button-box-on-rejected bb id)
      (track-handler! bb id)))
  (define (qt-on-button-box-clicked! bb handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-button-box-on-clicked bb id)
      (track-handler! bb id)))

  ;; -----------------------------------------------------------------------
  ;; Calendar
  ;; -----------------------------------------------------------------------

  (define qt-calendar-create
    (case-lambda
      [() (ffi-qt-calendar-create 0)]
      [(parent) (ffi-qt-calendar-create (or parent 0))]))

  (define (qt-calendar-set-selected-date! c year month day) (ffi-qt-calendar-set-selected-date c year month day))
  (define (qt-calendar-selected-year c) (ffi-qt-calendar-selected-year c))
  (define (qt-calendar-selected-month c) (ffi-qt-calendar-selected-month c))
  (define (qt-calendar-selected-day c) (ffi-qt-calendar-selected-day c))
  (define (qt-calendar-selected-date-string c) (ffi-qt-calendar-selected-date-string c))
  (define (qt-calendar-set-minimum-date! c year month day) (ffi-qt-calendar-set-minimum-date c year month day))
  (define (qt-calendar-set-maximum-date! c year month day) (ffi-qt-calendar-set-maximum-date c year month day))
  (define (qt-calendar-set-first-day-of-week! c day) (ffi-qt-calendar-set-first-day-of-week c day))
  (define (qt-calendar-set-grid-visible! c visible) (ffi-qt-calendar-set-grid-visible c (if visible 1 0)))
  (define (qt-calendar-grid-visible? c) (not (zero? (ffi-qt-calendar-is-grid-visible c))))
  (define (qt-calendar-set-navigation-bar-visible! c visible) (ffi-qt-calendar-set-navigation-bar-visible c (if visible 1 0)))

  (define (qt-on-calendar-selection-changed! c handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-calendar-on-selection-changed c id)
      (track-handler! c id)))
  (define (qt-on-calendar-clicked! c handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-calendar-on-clicked c id)
      (track-handler! c id)))

  ;; -----------------------------------------------------------------------
  ;; QSettings
  ;; -----------------------------------------------------------------------

  (define (qt-settings-create org app) (ffi-qt-settings-create org app))
  (define qt-settings-create-file
    (case-lambda
      [(path) (ffi-qt-settings-create-file path 1)]
      [(path format) (ffi-qt-settings-create-file path format)]))

  (define (qt-settings-set-string! s key value) (ffi-qt-settings-set-string s key value))
  (define qt-settings-value-string
    (case-lambda
      [(s key) (ffi-qt-settings-value-string s key "")]
      [(s key default) (ffi-qt-settings-value-string s key default)]))
  (define (qt-settings-set-int! s key value) (ffi-qt-settings-set-int s key value))
  (define qt-settings-value-int
    (case-lambda
      [(s key) (ffi-qt-settings-value-int s key 0)]
      [(s key default) (ffi-qt-settings-value-int s key default)]))
  (define (qt-settings-set-double! s key value) (ffi-qt-settings-set-double s key (exact->inexact value)))
  (define qt-settings-value-double
    (case-lambda
      [(s key) (ffi-qt-settings-value-double s key 0.0)]
      [(s key default) (ffi-qt-settings-value-double s key (exact->inexact default))]))
  (define (qt-settings-set-bool! s key value) (ffi-qt-settings-set-bool s key (if value 1 0)))
  (define qt-settings-value-bool
    (case-lambda
      [(s key) (not (zero? (ffi-qt-settings-value-bool s key 0)))]
      [(s key default) (not (zero? (ffi-qt-settings-value-bool s key (if default 1 0))))]))
  (define (qt-settings-contains? s key) (not (zero? (ffi-qt-settings-contains s key))))
  (define (qt-settings-remove! s key) (ffi-qt-settings-remove s key))
  (define (qt-settings-all-keys s) (string-split (ffi-qt-settings-all-keys s) #\newline))
  (define (qt-settings-child-keys s) (string-split (ffi-qt-settings-child-keys s) #\newline))
  (define (qt-settings-child-groups s) (string-split (ffi-qt-settings-child-groups s) #\newline))
  (define (qt-settings-begin-group! s prefix) (ffi-qt-settings-begin-group s prefix))
  (define (qt-settings-end-group! s) (ffi-qt-settings-end-group s))
  (define (qt-settings-group s) (ffi-qt-settings-group s))
  (define (qt-settings-sync! s) (ffi-qt-settings-sync s))
  (define (qt-settings-clear! s) (ffi-qt-settings-clear s))
  (define (qt-settings-file-name s) (ffi-qt-settings-file-name s))
  (define (qt-settings-writable? s) (not (zero? (ffi-qt-settings-is-writable s))))
  (define (qt-settings-destroy! s) (ffi-qt-settings-destroy s))

  ;; Helper for string-split (not in standard Chez)
  (define (string-split str ch)
    (let loop ([i 0] [start 0] [acc '()])
      (cond
        [(= i (string-length str))
         (reverse (if (= start i) acc (cons (substring str start i) acc)))]
        [(char=? (string-ref str i) ch)
         (loop (+ i 1) (+ i 1) (cons (substring str start i) acc))]
        [else (loop (+ i 1) start acc)])))

  ;; -----------------------------------------------------------------------
  ;; QCompleter
  ;; -----------------------------------------------------------------------

  (define (qt-completer-create items)
    (let ([items-str (if (list? items) (string-join items "\n") items)])
      (ffi-qt-completer-create items-str)))
  (define (qt-completer-set-model-strings! c items)
    (let ([items-str (if (list? items) (string-join items "\n") items)])
      (ffi-qt-completer-set-model-strings c items-str)))
  (define (qt-completer-set-case-sensitivity! c cs) (ffi-qt-completer-set-case-sensitivity c cs))
  (define (qt-completer-set-completion-mode! c mode) (ffi-qt-completer-set-completion-mode c mode))
  (define (qt-completer-set-filter-mode! c mode) (ffi-qt-completer-set-filter-mode c mode))
  (define (qt-completer-set-max-visible-items! c n) (ffi-qt-completer-set-max-visible-items c n))
  (define (qt-completer-completion-count c) (ffi-qt-completer-completion-count c))
  (define (qt-completer-current-completion c) (ffi-qt-completer-current-completion c))
  (define (qt-completer-set-completion-prefix! c prefix) (ffi-qt-completer-set-completion-prefix c prefix))

  (define (qt-on-completer-activated! c handler)
    (let ([id (register-string-handler! handler)])
      (ffi-qt-completer-on-activated c id)
      (track-handler! c id)))

  (define (qt-line-edit-set-completer! e c) (ffi-qt-line-edit-set-completer e (or c 0)))
  (define (qt-completer-destroy! c) (ffi-qt-completer-destroy c))

  ;; -----------------------------------------------------------------------
  ;; Tooltip / WhatsThis
  ;; -----------------------------------------------------------------------

  (define (qt-tooltip-show-text! x y text widget) (ffi-qt-tooltip-show-text x y text widget))
  (define (qt-tooltip-hide-text!) (ffi-qt-tooltip-hide-text))
  (define (qt-tooltip-visible?) (not (zero? (ffi-qt-tooltip-is-visible))))
  (define (qt-widget-tooltip w) (ffi-qt-widget-tooltip w))
  (define (qt-widget-set-whats-this! w text) (ffi-qt-widget-set-whats-this w text))
  (define (qt-widget-whats-this w) (ffi-qt-widget-whats-this w))

  ;; -----------------------------------------------------------------------
  ;; QStandardItemModel
  ;; -----------------------------------------------------------------------

  (define qt-standard-model-create
    (case-lambda
      [() (ffi-qt-standard-model-create 0 0 0)]
      [(rows cols) (ffi-qt-standard-model-create rows cols 0)]
      [(rows cols parent) (ffi-qt-standard-model-create rows cols (or parent 0))]))

  (define (qt-standard-model-destroy! m) (ffi-qt-standard-model-destroy m))
  (define (qt-standard-model-row-count m) (ffi-qt-standard-model-row-count m))
  (define (qt-standard-model-column-count m) (ffi-qt-standard-model-column-count m))
  (define (qt-standard-model-set-row-count! m n) (ffi-qt-standard-model-set-row-count m n))
  (define (qt-standard-model-set-column-count! m n) (ffi-qt-standard-model-set-column-count m n))
  (define (qt-standard-model-set-item! m row col item) (ffi-qt-standard-model-set-item m row col item))
  (define (qt-standard-model-item m row col) (ffi-qt-standard-model-item m row col))
  (define (qt-standard-model-insert-row! m row) (ffi-qt-standard-model-insert-row m row))
  (define (qt-standard-model-insert-column! m col) (ffi-qt-standard-model-insert-column m col))
  (define (qt-standard-model-remove-row! m row) (ffi-qt-standard-model-remove-row m row))
  (define (qt-standard-model-remove-column! m col) (ffi-qt-standard-model-remove-column m col))
  (define (qt-standard-model-clear! m) (ffi-qt-standard-model-clear m))
  (define (qt-standard-model-set-horizontal-header! m col text) (ffi-qt-standard-model-set-horizontal-header m col text))
  (define (qt-standard-model-set-vertical-header! m row text) (ffi-qt-standard-model-set-vertical-header m row text))

  ;; -----------------------------------------------------------------------
  ;; QStandardItem
  ;; -----------------------------------------------------------------------

  (define (qt-standard-item-create text) (ffi-qt-standard-item-create text))
  (define (qt-standard-item-text item) (ffi-qt-standard-item-text item))
  (define (qt-standard-item-set-text! item text) (ffi-qt-standard-item-set-text item text))
  (define (qt-standard-item-tooltip item) (ffi-qt-standard-item-tooltip item))
  (define (qt-standard-item-set-tooltip! item text) (ffi-qt-standard-item-set-tooltip item text))
  (define (qt-standard-item-set-editable! item val) (ffi-qt-standard-item-set-editable item (if val 1 0)))
  (define (qt-standard-item-editable? item) (not (zero? (ffi-qt-standard-item-is-editable item))))
  (define (qt-standard-item-set-enabled! item val) (ffi-qt-standard-item-set-enabled item (if val 1 0)))
  (define (qt-standard-item-enabled? item) (not (zero? (ffi-qt-standard-item-is-enabled item))))
  (define (qt-standard-item-set-selectable! item val) (ffi-qt-standard-item-set-selectable item (if val 1 0)))
  (define (qt-standard-item-selectable? item) (not (zero? (ffi-qt-standard-item-is-selectable item))))
  (define (qt-standard-item-set-checkable! item val) (ffi-qt-standard-item-set-checkable item (if val 1 0)))
  (define (qt-standard-item-checkable? item) (not (zero? (ffi-qt-standard-item-is-checkable item))))
  (define (qt-standard-item-set-check-state! item state) (ffi-qt-standard-item-set-check-state item state))
  (define (qt-standard-item-check-state item) (ffi-qt-standard-item-check-state item))
  (define (qt-standard-item-set-icon! item icon) (ffi-qt-standard-item-set-icon item icon))
  (define (qt-standard-item-append-row! parent child) (ffi-qt-standard-item-append-row parent child))
  (define (qt-standard-item-row-count item) (ffi-qt-standard-item-row-count item))
  (define (qt-standard-item-column-count item) (ffi-qt-standard-item-column-count item))
  (define (qt-standard-item-child item row col) (ffi-qt-standard-item-child item row col))

  ;; -----------------------------------------------------------------------
  ;; QStringListModel
  ;; -----------------------------------------------------------------------

  (define (qt-string-list-model-create items)
    (let ([items-str (if (list? items) (string-join items "\n") items)])
      (ffi-qt-string-list-model-create items-str)))
  (define (qt-string-list-model-destroy! m) (ffi-qt-string-list-model-destroy m))
  (define (qt-string-list-model-set-strings! m items)
    (let ([items-str (if (list? items) (string-join items "\n") items)])
      (ffi-qt-string-list-model-set-strings m items-str)))
  (define (qt-string-list-model-strings m) (string-split (ffi-qt-string-list-model-strings m) #\newline))
  (define (qt-string-list-model-row-count m) (ffi-qt-string-list-model-row-count m))

  ;; -----------------------------------------------------------------------
  ;; Views (common)
  ;; -----------------------------------------------------------------------

  (define (qt-view-set-model! v model) (ffi-qt-view-set-model v model))
  (define (qt-view-set-selection-mode! v mode) (ffi-qt-view-set-selection-mode v mode))
  (define (qt-view-set-selection-behavior! v behavior) (ffi-qt-view-set-selection-behavior v behavior))
  (define (qt-view-set-alternating-row-colors! v val)
    (ffi-qt-view-set-alternating-row-colors v (if val 1 0)))
  (define (qt-view-set-sorting-enabled! v val)
    (ffi-qt-view-set-sorting-enabled v (if val 1 0)))
  (define (qt-view-set-edit-triggers! v triggers) (ffi-qt-view-set-edit-triggers v triggers))

  ;; QListView
  (define qt-list-view-create
    (case-lambda
      [() (ffi-qt-list-view-create 0)]
      [(parent) (ffi-qt-list-view-create (or parent 0))]))
  (define (qt-list-view-set-flow! v flow) (ffi-qt-list-view-set-flow v flow))

  ;; QTableView
  (define qt-table-view-create
    (case-lambda
      [() (ffi-qt-table-view-create 0)]
      [(parent) (ffi-qt-table-view-create (or parent 0))]))
  (define (qt-table-view-set-column-width! v col w) (ffi-qt-table-view-set-column-width v col w))
  (define (qt-table-view-set-row-height! v row h) (ffi-qt-table-view-set-row-height v row h))
  (define (qt-table-view-hide-column! v col) (ffi-qt-table-view-hide-column v col))
  (define (qt-table-view-show-column! v col) (ffi-qt-table-view-show-column v col))
  (define (qt-table-view-hide-row! v row) (ffi-qt-table-view-hide-row v row))
  (define (qt-table-view-show-row! v row) (ffi-qt-table-view-show-row v row))
  (define (qt-table-view-resize-columns-to-contents! v) (ffi-qt-table-view-resize-columns-to-contents v))
  (define (qt-table-view-resize-rows-to-contents! v) (ffi-qt-table-view-resize-rows-to-contents v))

  ;; QTreeView
  (define qt-tree-view-create
    (case-lambda
      [() (ffi-qt-tree-view-create 0)]
      [(parent) (ffi-qt-tree-view-create (or parent 0))]))
  (define (qt-tree-view-expand-all! v) (ffi-qt-tree-view-expand-all v))
  (define (qt-tree-view-collapse-all! v) (ffi-qt-tree-view-collapse-all v))
  (define (qt-tree-view-set-indentation! v indent) (ffi-qt-tree-view-set-indentation v indent))
  (define (qt-tree-view-indentation v) (ffi-qt-tree-view-indentation v))
  (define (qt-tree-view-set-root-is-decorated! v val)
    (ffi-qt-tree-view-set-root-is-decorated v (if val 1 0)))
  (define (qt-tree-view-set-header-hidden! v val)
    (ffi-qt-tree-view-set-header-hidden v (if val 1 0)))
  (define (qt-tree-view-set-column-width! v col w) (ffi-qt-tree-view-set-column-width v col w))

  ;; QHeaderView (via view)
  (define (qt-view-header-set-stretch-last-section! v horizontal val)
    (ffi-qt-view-header-set-stretch-last-section v (if horizontal 1 0) (if val 1 0)))
  (define (qt-view-header-set-section-resize-mode! v horizontal mode)
    (ffi-qt-view-header-set-section-resize-mode v (if horizontal 1 0) mode))
  (define (qt-view-header-hide! v horizontal)
    (ffi-qt-view-header-hide v (if horizontal 1 0)))
  (define (qt-view-header-show! v horizontal)
    (ffi-qt-view-header-show v (if horizontal 1 0)))
  (define (qt-view-header-set-default-section-size! v horizontal size)
    (ffi-qt-view-header-set-default-section-size v (if horizontal 1 0) size))

  ;; -----------------------------------------------------------------------
  ;; QSortFilterProxyModel
  ;; -----------------------------------------------------------------------

  (define qt-sort-filter-proxy-create
    (case-lambda
      [() (ffi-qt-sort-filter-proxy-create 0)]
      [(parent) (ffi-qt-sort-filter-proxy-create (or parent 0))]))
  (define (qt-sort-filter-proxy-destroy! p) (ffi-qt-sort-filter-proxy-destroy p))
  (define (qt-sort-filter-proxy-set-source-model! p model) (ffi-qt-sort-filter-proxy-set-source-model p model))
  (define (qt-sort-filter-proxy-set-filter-regex! p pattern) (ffi-qt-sort-filter-proxy-set-filter-regex p pattern))
  (define (qt-sort-filter-proxy-set-filter-column! p col) (ffi-qt-sort-filter-proxy-set-filter-column p col))
  (define (qt-sort-filter-proxy-set-filter-case-sensitivity! p cs) (ffi-qt-sort-filter-proxy-set-filter-case-sensitivity p cs))
  (define (qt-sort-filter-proxy-set-filter-role! p role) (ffi-qt-sort-filter-proxy-set-filter-role p role))
  (define (qt-sort-filter-proxy-sort! p col order) (ffi-qt-sort-filter-proxy-sort p col order))
  (define (qt-sort-filter-proxy-set-sort-role! p role) (ffi-qt-sort-filter-proxy-set-sort-role p role))
  (define (qt-sort-filter-proxy-set-dynamic-sort-filter! p val)
    (ffi-qt-sort-filter-proxy-set-dynamic-sort-filter p (if val 1 0)))
  (define (qt-sort-filter-proxy-invalidate-filter! p) (ffi-qt-sort-filter-proxy-invalidate-filter p))
  (define (qt-sort-filter-proxy-row-count p) (ffi-qt-sort-filter-proxy-row-count p))

  ;; -----------------------------------------------------------------------
  ;; View signals + selection
  ;; -----------------------------------------------------------------------

  (define (qt-on-view-clicked! v handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-view-on-clicked v id)
      (track-handler! v id)))
  (define (qt-on-view-double-clicked! v handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-view-on-double-clicked v id)
      (track-handler! v id)))
  (define (qt-on-view-activated! v handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-view-on-activated v id)
      (track-handler! v id)))
  (define (qt-on-view-selection-changed! v handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-view-on-selection-changed v id)
      (track-handler! v id)))
  (define (qt-view-last-clicked-row) (ffi-qt-view-last-clicked-row))
  (define (qt-view-last-clicked-col) (ffi-qt-view-last-clicked-col))
  (define (qt-view-selected-rows v) (string-split (ffi-qt-view-selected-rows v) #\newline))
  (define (qt-view-current-row v) (ffi-qt-view-current-row v))

  ;; -----------------------------------------------------------------------
  ;; Validators
  ;; -----------------------------------------------------------------------

  (define qt-int-validator-create
    (case-lambda
      [(min max) (ffi-qt-int-validator-create min max 0)]
      [(min max parent) (ffi-qt-int-validator-create min max (or parent 0))]))
  (define qt-double-validator-create
    (case-lambda
      [(bottom top decimals) (ffi-qt-double-validator-create (exact->inexact bottom) (exact->inexact top) decimals 0)]
      [(bottom top decimals parent) (ffi-qt-double-validator-create (exact->inexact bottom) (exact->inexact top) decimals (or parent 0))]))
  (define qt-regex-validator-create
    (case-lambda
      [(pattern) (ffi-qt-regex-validator-create pattern 0)]
      [(pattern parent) (ffi-qt-regex-validator-create pattern (or parent 0))]))
  (define (qt-validator-destroy! v) (ffi-qt-validator-destroy v))
  (define (qt-validator-validate v input) (ffi-qt-validator-validate v input))
  (define (qt-line-edit-set-validator! e v) (ffi-qt-line-edit-set-validator e v))
  (define (qt-line-edit-has-acceptable-input? e) (not (zero? (ffi-qt-line-edit-has-acceptable-input e))))

  ;; -----------------------------------------------------------------------
  ;; QPlainTextEdit
  ;; -----------------------------------------------------------------------

  (define qt-plain-text-edit-create
    (case-lambda
      [() (ffi-qt-plain-text-edit-create 0)]
      [(parent) (ffi-qt-plain-text-edit-create (or parent 0))]))

  (define (qt-plain-text-edit-set-text! e text) (ffi-qt-plain-text-edit-set-text e text))
  (define (qt-plain-text-edit-text e) (ffi-qt-plain-text-edit-text e))
  (define (qt-plain-text-edit-append! e text) (ffi-qt-plain-text-edit-append e text))
  (define (qt-plain-text-edit-clear! e) (ffi-qt-plain-text-edit-clear e))
  (define (qt-plain-text-edit-set-read-only! e val) (ffi-qt-plain-text-edit-set-read-only e (if val 1 0)))
  (define (qt-plain-text-edit-read-only? e) (not (zero? (ffi-qt-plain-text-edit-is-read-only e))))
  (define (qt-plain-text-edit-set-placeholder! e text) (ffi-qt-plain-text-edit-set-placeholder e text))
  (define (qt-plain-text-edit-line-count e) (ffi-qt-plain-text-edit-line-count e))
  (define (qt-plain-text-edit-set-max-block-count! e n) (ffi-qt-plain-text-edit-set-max-block-count e n))
  (define (qt-plain-text-edit-cursor-line e) (ffi-qt-plain-text-edit-cursor-line e))
  (define (qt-plain-text-edit-cursor-column e) (ffi-qt-plain-text-edit-cursor-column e))
  (define (qt-plain-text-edit-set-line-wrap! e mode) (ffi-qt-plain-text-edit-set-line-wrap e mode))

  (define (qt-on-plain-text-changed! e handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-plain-text-edit-on-text-changed e id)
      (track-handler! e id)))

  ;; Editor extensions
  (define (qt-plain-text-edit-cursor-position e) (ffi-qt-plain-text-edit-cursor-position e))
  (define (qt-plain-text-edit-set-cursor-position! e pos) (ffi-qt-plain-text-edit-set-cursor-position e pos))
  (define qt-plain-text-edit-move-cursor!
    (case-lambda
      [(e op) (ffi-qt-plain-text-edit-move-cursor e op ffi-qt-const-move-anchor)]
      [(e op mode) (ffi-qt-plain-text-edit-move-cursor e op mode)]))
  (define (qt-plain-text-edit-select-all! e) (ffi-qt-plain-text-edit-select-all e))
  (define (qt-plain-text-edit-selected-text e) (ffi-qt-plain-text-edit-selected-text e))
  (define (qt-plain-text-edit-selection-start e) (ffi-qt-plain-text-edit-selection-start e))
  (define (qt-plain-text-edit-selection-end e) (ffi-qt-plain-text-edit-selection-end e))
  (define (qt-plain-text-edit-set-selection! e start end) (ffi-qt-plain-text-edit-set-selection e start end))
  (define (qt-plain-text-edit-has-selection? e) (not (zero? (ffi-qt-plain-text-edit-has-selection e))))
  (define (qt-plain-text-edit-insert-text! e text) (ffi-qt-plain-text-edit-insert-text e text))
  (define (qt-plain-text-edit-remove-selected-text! e) (ffi-qt-plain-text-edit-remove-selected-text e))
  (define (qt-plain-text-edit-undo! e) (ffi-qt-plain-text-edit-undo e))
  (define (qt-plain-text-edit-redo! e) (ffi-qt-plain-text-edit-redo e))
  (define (qt-plain-text-edit-can-undo? e) (not (zero? (ffi-qt-plain-text-edit-can-undo e))))
  (define (qt-plain-text-edit-cut! e) (ffi-qt-plain-text-edit-cut e))
  (define (qt-plain-text-edit-copy! e) (ffi-qt-plain-text-edit-copy e))
  (define (qt-plain-text-edit-paste! e) (ffi-qt-plain-text-edit-paste e))
  (define (qt-plain-text-edit-text-length e) (ffi-qt-plain-text-edit-text-length e))
  (define (qt-plain-text-edit-text-range e start end) (ffi-qt-plain-text-edit-text-range e start end))
  (define (qt-plain-text-edit-line-from-position e pos) (ffi-qt-plain-text-edit-line-from-position e pos))
  (define (qt-plain-text-edit-line-end-position e line) (ffi-qt-plain-text-edit-line-end-position e line))
  (define (qt-plain-text-edit-find-text e text flags) (not (zero? (ffi-qt-plain-text-edit-find-text e text flags))))
  (define (qt-plain-text-edit-ensure-cursor-visible! e) (ffi-qt-plain-text-edit-ensure-cursor-visible e))
  (define (qt-plain-text-edit-center-cursor! e) (ffi-qt-plain-text-edit-center-cursor e))
  (define (qt-text-document-create) (ffi-qt-text-document-create))
  (define (qt-plain-text-document-create) (ffi-qt-plain-text-document-create))
  (define (qt-text-document-destroy! doc) (ffi-qt-text-document-destroy doc))
  (define (qt-plain-text-edit-document e) (ffi-qt-plain-text-edit-document e))
  (define (qt-plain-text-edit-set-document! e doc) (ffi-qt-plain-text-edit-set-document e doc))
  (define (qt-text-document-modified? doc) (not (zero? (ffi-qt-text-document-is-modified doc))))
  (define (qt-text-document-set-modified! doc val) (ffi-qt-text-document-set-modified doc (if val 1 0)))

  ;; -----------------------------------------------------------------------
  ;; QToolButton
  ;; -----------------------------------------------------------------------

  (define qt-tool-button-create
    (case-lambda
      [() (ffi-qt-tool-button-create 0)]
      [(parent) (ffi-qt-tool-button-create (or parent 0))]))
  (define (qt-tool-button-set-text! b text) (ffi-qt-tool-button-set-text b text))
  (define (qt-tool-button-text b) (ffi-qt-tool-button-text b))
  (define (qt-tool-button-set-icon! b path) (ffi-qt-tool-button-set-icon b path))
  (define (qt-tool-button-set-menu! b menu) (ffi-qt-tool-button-set-menu b menu))
  (define (qt-tool-button-set-popup-mode! b mode) (ffi-qt-tool-button-set-popup-mode b mode))
  (define (qt-tool-button-set-auto-raise! b val) (ffi-qt-tool-button-set-auto-raise b (if val 1 0)))
  (define (qt-tool-button-set-arrow-type! b arrow) (ffi-qt-tool-button-set-arrow-type b arrow))
  (define (qt-tool-button-set-tool-button-style! b style) (ffi-qt-tool-button-set-tool-button-style b style))

  (define (qt-on-tool-button-clicked! b handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-tool-button-on-clicked b id)
      (track-handler! b id)))

  ;; -----------------------------------------------------------------------
  ;; Layout spacers / Size policy
  ;; -----------------------------------------------------------------------

  (define (qt-layout-add-spacing! layout size) (ffi-qt-layout-add-spacing layout size))
  (define (qt-widget-set-size-policy! w h-policy v-policy)
    (ffi-qt-widget-set-size-policy w h-policy v-policy))
  (define (qt-layout-set-stretch-factor! layout widget stretch)
    (ffi-qt-layout-set-stretch-factor layout widget stretch))

  ;; -----------------------------------------------------------------------
  ;; Graphics Scene
  ;; -----------------------------------------------------------------------

  (define qt-graphics-scene-create
    (case-lambda
      [() (ffi-qt-graphics-scene-create 0.0 0.0 1000.0 1000.0)]
      [(x y w h) (ffi-qt-graphics-scene-create
                   (exact->inexact x) (exact->inexact y)
                   (exact->inexact w) (exact->inexact h))]))

  (define (qt-graphics-scene-add-rect! scene x y w h)
    (ffi-qt-graphics-scene-add-rect scene (exact->inexact x) (exact->inexact y) (exact->inexact w) (exact->inexact h)))
  (define (qt-graphics-scene-add-ellipse! scene x y w h)
    (ffi-qt-graphics-scene-add-ellipse scene (exact->inexact x) (exact->inexact y) (exact->inexact w) (exact->inexact h)))
  (define (qt-graphics-scene-add-line! scene x1 y1 x2 y2)
    (ffi-qt-graphics-scene-add-line scene (exact->inexact x1) (exact->inexact y1) (exact->inexact x2) (exact->inexact y2)))
  (define (qt-graphics-scene-add-text! scene text) (ffi-qt-graphics-scene-add-text scene text))
  (define (qt-graphics-scene-add-pixmap! scene pm) (ffi-qt-graphics-scene-add-pixmap scene pm))
  (define (qt-graphics-scene-remove-item! scene item) (ffi-qt-graphics-scene-remove-item scene item))
  (define (qt-graphics-scene-clear! scene) (ffi-qt-graphics-scene-clear scene))
  (define (qt-graphics-scene-items-count scene) (ffi-qt-graphics-scene-items-count scene))
  (define (qt-graphics-scene-set-background! scene r g b) (ffi-qt-graphics-scene-set-background scene r g b))
  (define (qt-graphics-scene-destroy! scene) (ffi-qt-graphics-scene-destroy scene))

  ;; -----------------------------------------------------------------------
  ;; Graphics View
  ;; -----------------------------------------------------------------------

  (define qt-graphics-view-create
    (case-lambda
      [(scene) (ffi-qt-graphics-view-create scene 0)]
      [(scene parent) (ffi-qt-graphics-view-create scene (or parent 0))]))

  (define (qt-graphics-view-set-render-hint! v hint on)
    (ffi-qt-graphics-view-set-render-hint v hint (if on 1 0)))
  (define (qt-graphics-view-set-drag-mode! v mode) (ffi-qt-graphics-view-set-drag-mode v mode))
  (define (qt-graphics-view-fit-in-view! v) (ffi-qt-graphics-view-fit-in-view v))
  (define (qt-graphics-view-scale! v sx sy)
    (ffi-qt-graphics-view-scale v (exact->inexact sx) (exact->inexact sy)))
  (define (qt-graphics-view-center-on! v x y)
    (ffi-qt-graphics-view-center-on v (exact->inexact x) (exact->inexact y)))

  ;; -----------------------------------------------------------------------
  ;; Graphics Item
  ;; -----------------------------------------------------------------------

  (define (qt-graphics-item-set-pos! item x y)
    (ffi-qt-graphics-item-set-pos item (exact->inexact x) (exact->inexact y)))
  (define (qt-graphics-item-x item) (ffi-qt-graphics-item-x item))
  (define (qt-graphics-item-y item) (ffi-qt-graphics-item-y item))
  (define (qt-graphics-item-set-pen! item r g b w)
    (ffi-qt-graphics-item-set-pen item r g b w))
  (define (qt-graphics-item-set-brush! item r g b)
    (ffi-qt-graphics-item-set-brush item r g b))
  (define (qt-graphics-item-set-flags! item flags) (ffi-qt-graphics-item-set-flags item flags))
  (define (qt-graphics-item-set-tooltip! item text) (ffi-qt-graphics-item-set-tooltip item text))
  (define (qt-graphics-item-set-zvalue! item z)
    (ffi-qt-graphics-item-set-zvalue item (exact->inexact z)))
  (define (qt-graphics-item-zvalue item) (ffi-qt-graphics-item-zvalue item))
  (define (qt-graphics-item-set-rotation! item angle)
    (ffi-qt-graphics-item-set-rotation item (exact->inexact angle)))
  (define (qt-graphics-item-set-scale! item factor)
    (ffi-qt-graphics-item-set-scale item (exact->inexact factor)))
  (define (qt-graphics-item-set-visible! item visible)
    (ffi-qt-graphics-item-set-visible item (if visible 1 0)))

  ;; -----------------------------------------------------------------------
  ;; Paint Widget
  ;; -----------------------------------------------------------------------

  (define qt-paint-widget-create
    (case-lambda
      [() (ffi-qt-paint-widget-create 0)]
      [(parent) (ffi-qt-paint-widget-create (or parent 0))]))

  (define (qt-on-paint! w handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-paint-widget-on-paint w id)
      (track-handler! w id)))

  (define (qt-paint-widget-painter w) (ffi-qt-paint-widget-painter w))
  (define (qt-paint-widget-update! w) (ffi-qt-paint-widget-update w))
  (define (qt-paint-widget-width w) (ffi-qt-paint-widget-width w))
  (define (qt-paint-widget-height w) (ffi-qt-paint-widget-height w))

  ;; -----------------------------------------------------------------------
  ;; QProcess
  ;; -----------------------------------------------------------------------

  (define qt-process-create
    (case-lambda
      [() (ffi-qt-process-create 0)]
      [(parent) (ffi-qt-process-create (or parent 0))]))

  (define (qt-process-start! proc program args)
    (let ([args-str (if (list? args) (string-join args "\n") args)])
      (ffi-qt-process-start proc program args-str)))
  (define (qt-process-write! proc data) (ffi-qt-process-write proc data))
  (define (qt-process-close-write! proc) (ffi-qt-process-close-write proc))
  (define (qt-process-read-stdout proc) (ffi-qt-process-read-stdout proc))
  (define (qt-process-read-stderr proc) (ffi-qt-process-read-stderr proc))
  (define (qt-process-wait-for-finished! proc msecs) (ffi-qt-process-wait-for-finished proc msecs))
  (define (qt-process-exit-code proc) (ffi-qt-process-exit-code proc))
  (define (qt-process-state proc) (ffi-qt-process-state proc))
  (define (qt-process-kill! proc) (ffi-qt-process-kill proc))
  (define (qt-process-terminate! proc) (ffi-qt-process-terminate proc))

  (define (qt-on-process-finished! proc handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-process-on-finished proc id)
      (track-handler! proc id)))
  (define (qt-on-process-ready-read! proc handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-process-on-ready-read proc id)
      (track-handler! proc id)))
  (define (qt-process-destroy! proc) (ffi-qt-process-destroy proc))

  ;; -----------------------------------------------------------------------
  ;; QWizard / QWizardPage
  ;; -----------------------------------------------------------------------

  (define qt-wizard-create
    (case-lambda
      [() (ffi-qt-wizard-create 0)]
      [(parent) (ffi-qt-wizard-create (or parent 0))]))
  (define (qt-wizard-add-page! wiz page) (ffi-qt-wizard-add-page wiz page))
  (define (qt-wizard-set-start-id! wiz id) (ffi-qt-wizard-set-start-id wiz id))
  (define (qt-wizard-current-id wiz) (ffi-qt-wizard-current-id wiz))
  (define (qt-wizard-set-title! wiz title) (ffi-qt-wizard-set-title wiz title))
  (define (qt-wizard-exec! wiz) (ffi-qt-wizard-exec wiz))

  (define qt-wizard-page-create
    (case-lambda
      [() (ffi-qt-wizard-page-create 0)]
      [(parent) (ffi-qt-wizard-page-create (or parent 0))]))
  (define (qt-wizard-page-set-title! page title) (ffi-qt-wizard-page-set-title page title))
  (define (qt-wizard-page-set-subtitle! page subtitle) (ffi-qt-wizard-page-set-subtitle page subtitle))
  (define (qt-wizard-page-set-layout! page layout) (ffi-qt-wizard-page-set-layout page layout))

  (define (qt-on-wizard-current-changed! wiz handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-wizard-on-current-changed wiz id)
      (track-handler! wiz id)))

  ;; -----------------------------------------------------------------------
  ;; QMdiArea / QMdiSubWindow
  ;; -----------------------------------------------------------------------

  (define qt-mdi-area-create
    (case-lambda
      [() (ffi-qt-mdi-area-create 0)]
      [(parent) (ffi-qt-mdi-area-create (or parent 0))]))
  (define (qt-mdi-area-add-sub-window! area widget) (ffi-qt-mdi-area-add-sub-window area widget))
  (define (qt-mdi-area-remove-sub-window! area sub) (ffi-qt-mdi-area-remove-sub-window area sub))
  (define (qt-mdi-area-active-sub-window area) (ffi-qt-mdi-area-active-sub-window area))
  (define (qt-mdi-area-sub-window-count area) (ffi-qt-mdi-area-sub-window-count area))
  (define (qt-mdi-area-cascade! area) (ffi-qt-mdi-area-cascade area))
  (define (qt-mdi-area-tile! area) (ffi-qt-mdi-area-tile area))
  (define (qt-mdi-area-set-view-mode! area mode) (ffi-qt-mdi-area-set-view-mode area mode))
  (define (qt-mdi-sub-window-set-title! sub title) (ffi-qt-mdi-sub-window-set-title sub title))

  (define (qt-on-mdi-sub-window-activated! area handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-mdi-area-on-sub-window-activated area id)
      (track-handler! area id)))

  ;; -----------------------------------------------------------------------
  ;; QDial
  ;; -----------------------------------------------------------------------

  (define qt-dial-create
    (case-lambda
      [() (ffi-qt-dial-create 0)]
      [(parent) (ffi-qt-dial-create (or parent 0))]))
  (define (qt-dial-set-value! d val) (ffi-qt-dial-set-value d val))
  (define (qt-dial-value d) (ffi-qt-dial-value d))
  (define (qt-dial-set-range! d min max) (ffi-qt-dial-set-range d min max))
  (define (qt-dial-set-notches-visible! d visible)
    (ffi-qt-dial-set-notches-visible d (if visible 1 0)))
  (define (qt-dial-set-wrapping! d wrap)
    (ffi-qt-dial-set-wrapping d (if wrap 1 0)))

  (define (qt-on-dial-value-changed! d handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-dial-on-value-changed d id)
      (track-handler! d id)))

  ;; -----------------------------------------------------------------------
  ;; QLCDNumber
  ;; -----------------------------------------------------------------------

  (define qt-lcd-create
    (case-lambda
      [() (ffi-qt-lcd-create 5 0)]
      [(digits) (ffi-qt-lcd-create digits 0)]
      [(digits parent) (ffi-qt-lcd-create digits (or parent 0))]))
  (define (qt-lcd-display-int! lcd val) (ffi-qt-lcd-display-int lcd val))
  (define (qt-lcd-display-double! lcd val) (ffi-qt-lcd-display-double lcd (exact->inexact val)))
  (define (qt-lcd-display-string! lcd text) (ffi-qt-lcd-display-string lcd text))
  (define (qt-lcd-set-mode! lcd mode) (ffi-qt-lcd-set-mode lcd mode))
  (define (qt-lcd-set-segment-style! lcd style) (ffi-qt-lcd-set-segment-style lcd style))

  ;; -----------------------------------------------------------------------
  ;; QToolBox
  ;; -----------------------------------------------------------------------

  (define qt-tool-box-create
    (case-lambda
      [() (ffi-qt-tool-box-create 0)]
      [(parent) (ffi-qt-tool-box-create (or parent 0))]))
  (define (qt-tool-box-add-item! tb widget text) (ffi-qt-tool-box-add-item tb widget text))
  (define (qt-tool-box-set-current-index! tb idx) (ffi-qt-tool-box-set-current-index tb idx))
  (define (qt-tool-box-current-index tb) (ffi-qt-tool-box-current-index tb))
  (define (qt-tool-box-count tb) (ffi-qt-tool-box-count tb))
  (define (qt-tool-box-set-item-text! tb idx text) (ffi-qt-tool-box-set-item-text tb idx text))

  (define (qt-on-tool-box-current-changed! tb handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-tool-box-on-current-changed tb id)
      (track-handler! tb id)))

  ;; -----------------------------------------------------------------------
  ;; QUndoStack
  ;; -----------------------------------------------------------------------

  (define qt-undo-stack-create
    (case-lambda
      [() (ffi-qt-undo-stack-create 0)]
      [(parent) (ffi-qt-undo-stack-create (or parent 0))]))

  (define (qt-undo-stack-push! stack text undo-handler redo-handler cleanup-handler)
    (let ([undo-id (register-void-handler! undo-handler)]
          [redo-id (register-void-handler! redo-handler)]
          [cleanup-id (register-void-handler! cleanup-handler)])
      (ffi-qt-undo-stack-push stack text
        (foreign-callable-entry-point void-trampoline) undo-id
        (foreign-callable-entry-point void-trampoline) redo-id
        (foreign-callable-entry-point void-trampoline) cleanup-id)))

  (define (qt-undo-stack-undo! stack) (ffi-qt-undo-stack-undo stack))
  (define (qt-undo-stack-redo! stack) (ffi-qt-undo-stack-redo stack))
  (define (qt-undo-stack-can-undo? stack) (not (zero? (ffi-qt-undo-stack-can-undo stack))))
  (define (qt-undo-stack-can-redo? stack) (not (zero? (ffi-qt-undo-stack-can-redo stack))))
  (define (qt-undo-stack-undo-text stack) (ffi-qt-undo-stack-undo-text stack))
  (define (qt-undo-stack-redo-text stack) (ffi-qt-undo-stack-redo-text stack))
  (define (qt-undo-stack-clear! stack) (ffi-qt-undo-stack-clear stack))
  (define qt-undo-stack-create-undo-action
    (case-lambda
      [(stack) (ffi-qt-undo-stack-create-undo-action stack 0)]
      [(stack parent) (ffi-qt-undo-stack-create-undo-action stack (or parent 0))]))
  (define qt-undo-stack-create-redo-action
    (case-lambda
      [(stack) (ffi-qt-undo-stack-create-redo-action stack 0)]
      [(stack parent) (ffi-qt-undo-stack-create-redo-action stack (or parent 0))]))
  (define (qt-undo-stack-destroy! stack) (ffi-qt-undo-stack-destroy stack))

  ;; -----------------------------------------------------------------------
  ;; QFileSystemModel
  ;; -----------------------------------------------------------------------

  (define qt-file-system-model-create
    (case-lambda
      [() (ffi-qt-file-system-model-create 0)]
      [(parent) (ffi-qt-file-system-model-create (or parent 0))]))
  (define (qt-file-system-model-set-root-path! model path) (ffi-qt-file-system-model-set-root-path model path))
  (define (qt-file-system-model-set-filter! model filters) (ffi-qt-file-system-model-set-filter model filters))
  (define (qt-file-system-model-set-name-filters! model patterns)
    (let ([p (if (list? patterns) (string-join patterns "\n") patterns)])
      (ffi-qt-file-system-model-set-name-filters model p)))
  (define (qt-file-system-model-file-path model row col)
    (ffi-qt-file-system-model-file-path model row col))
  (define (qt-tree-view-set-file-system-root! view model path)
    (ffi-qt-tree-view-set-file-system-root view model path))
  (define (qt-file-system-model-destroy! model) (ffi-qt-file-system-model-destroy model))

  ;; -----------------------------------------------------------------------
  ;; QSyntaxHighlighter
  ;; -----------------------------------------------------------------------

  (define (qt-syntax-highlighter-create doc) (ffi-qt-syntax-highlighter-create doc))
  (define (qt-syntax-highlighter-destroy! h) (ffi-qt-syntax-highlighter-destroy h))
  (define (qt-syntax-highlighter-add-rule! h pattern fg-r fg-g fg-b bold italic)
    (ffi-qt-syntax-highlighter-add-rule h pattern fg-r fg-g fg-b (if bold 1 0) (if italic 1 0)))
  (define (qt-syntax-highlighter-add-keywords! h keywords fg-r fg-g fg-b bold italic)
    (let ([kw (if (list? keywords) (string-join keywords " ") keywords)])
      (ffi-qt-syntax-highlighter-add-keywords h kw fg-r fg-g fg-b (if bold 1 0) (if italic 1 0))))
  (define (qt-syntax-highlighter-add-multiline-rule! h start-pat end-pat fg-r fg-g fg-b bold italic)
    (ffi-qt-syntax-highlighter-add-multiline-rule h start-pat end-pat fg-r fg-g fg-b (if bold 1 0) (if italic 1 0)))
  (define (qt-syntax-highlighter-clear-rules! h) (ffi-qt-syntax-highlighter-clear-rules h))
  (define (qt-syntax-highlighter-rehighlight! h) (ffi-qt-syntax-highlighter-rehighlight h))

  ;; -----------------------------------------------------------------------
  ;; Line number area
  ;; -----------------------------------------------------------------------

  (define (qt-line-number-area-create editor) (ffi-qt-line-number-area-create editor))
  (define (qt-line-number-area-destroy! area) (ffi-qt-line-number-area-destroy area))
  (define (qt-line-number-area-set-visible! area visible)
    (ffi-qt-line-number-area-set-visible area (if visible 1 0)))
  (define (qt-line-number-area-set-bg-color! area r g b) (ffi-qt-line-number-area-set-bg-color area r g b))
  (define (qt-line-number-area-set-fg-color! area r g b) (ffi-qt-line-number-area-set-fg-color area r g b))

  ;; -----------------------------------------------------------------------
  ;; Extra selections
  ;; -----------------------------------------------------------------------

  (define (qt-plain-text-edit-clear-extra-selections! e) (ffi-qt-plain-text-edit-clear-extra-selections e))
  (define (qt-plain-text-edit-add-extra-selection-line! e line bg-r bg-g bg-b)
    (ffi-qt-plain-text-edit-add-extra-selection-line e line bg-r bg-g bg-b))
  (define (qt-plain-text-edit-add-extra-selection-range! e start length fg-r fg-g fg-b bg-r bg-g bg-b bold)
    (ffi-qt-plain-text-edit-add-extra-selection-range e start length fg-r fg-g fg-b bg-r bg-g bg-b (if bold 1 0)))
  (define (qt-plain-text-edit-apply-extra-selections! e)
    (ffi-qt-plain-text-edit-apply-extra-selections e))

  ;; -----------------------------------------------------------------------
  ;; Completer on editor
  ;; -----------------------------------------------------------------------

  (define (qt-completer-set-widget! c w) (ffi-qt-completer-set-widget c w))
  (define (qt-completer-complete-rect! c x y w h) (ffi-qt-completer-complete-rect c x y w h))

  ;; -----------------------------------------------------------------------
  ;; QScintilla
  ;; -----------------------------------------------------------------------

  (define qt-scintilla-create
    (case-lambda
      [() (ffi-qt-scintilla-create 0)]
      [(parent) (ffi-qt-scintilla-create (or parent 0))]))
  (define (qt-scintilla-destroy! sci) (ffi-qt-scintilla-destroy sci))
  (define (qt-scintilla-send-message sci msg wparam lparam)
    (ffi-qt-scintilla-send-message sci msg wparam lparam))
  (define (qt-scintilla-send-message-string sci msg wparam str)
    (ffi-qt-scintilla-send-message-string sci msg wparam str))
  (define (qt-scintilla-receive-string sci msg wparam)
    (ffi-qt-scintilla-receive-string sci msg wparam))
  (define (qt-scintilla-set-text! sci text) (ffi-qt-scintilla-set-text sci text))
  (define (qt-scintilla-get-text sci) (ffi-qt-scintilla-get-text sci))
  (define (qt-scintilla-get-text-length sci) (ffi-qt-scintilla-get-text-length sci))
  (define (qt-scintilla-set-lexer-language! sci lang) (ffi-qt-scintilla-set-lexer-language sci lang))
  (define (qt-scintilla-get-lexer-language sci) (ffi-qt-scintilla-get-lexer-language sci))
  (define (qt-scintilla-set-read-only! sci val) (ffi-qt-scintilla-set-read-only sci (if val 1 0)))
  (define (qt-scintilla-read-only? sci) (not (zero? (ffi-qt-scintilla-is-read-only sci))))
  (define (qt-scintilla-set-margin-width! sci margin width) (ffi-qt-scintilla-set-margin-width sci margin width))
  (define (qt-scintilla-set-margin-type! sci margin type) (ffi-qt-scintilla-set-margin-type sci margin type))
  (define (qt-scintilla-set-focus! sci) (ffi-qt-scintilla-set-focus sci))

  (define (qt-on-scintilla-text-changed! sci handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-scintilla-on-text-changed sci id)
      (track-handler! sci id)))
  (define (qt-on-scintilla-char-added! sci handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-scintilla-on-char-added sci id)
      (track-handler! sci id)))
  (define (qt-on-scintilla-save-point-reached! sci handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-scintilla-on-save-point-reached sci id)
      (track-handler! sci id)))
  (define (qt-on-scintilla-save-point-left! sci handler)
    (let ([id (register-void-handler! handler)])
      (ffi-qt-scintilla-on-save-point-left sci id)
      (track-handler! sci id)))
  (define (qt-on-scintilla-margin-clicked! sci handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-scintilla-on-margin-clicked sci id)
      (track-handler! sci id)))
  (define (qt-on-scintilla-modified! sci handler)
    (let ([id (register-int-handler! handler)])
      (ffi-qt-scintilla-on-modified sci id)
      (track-handler! sci id)))

  ;; -----------------------------------------------------------------------
  ;; Additional Constants
  ;; -----------------------------------------------------------------------

  (define QT_FRAME_NO_FRAME      ffi-qt-const-frame-no-frame)
  (define QT_FRAME_BOX           ffi-qt-const-frame-box)
  (define QT_FRAME_PANEL         ffi-qt-const-frame-panel)
  (define QT_FRAME_WIN_PANEL     ffi-qt-const-frame-win-panel)
  (define QT_FRAME_HLINE         ffi-qt-const-frame-hline)
  (define QT_FRAME_VLINE         ffi-qt-const-frame-vline)
  (define QT_FRAME_STYLED_PANEL  ffi-qt-const-frame-styled-panel)
  (define QT_FRAME_PLAIN         ffi-qt-const-frame-plain)
  (define QT_FRAME_RAISED        ffi-qt-const-frame-raised)
  (define QT_FRAME_SUNKEN        ffi-qt-const-frame-sunken)

  (define QT_BUTTON_OK       ffi-qt-const-button-ok)
  (define QT_BUTTON_CANCEL   ffi-qt-const-button-cancel)
  (define QT_BUTTON_APPLY    ffi-qt-const-button-apply)
  (define QT_BUTTON_CLOSE    ffi-qt-const-button-close)
  (define QT_BUTTON_YES      ffi-qt-const-button-yes)
  (define QT_BUTTON_NO       ffi-qt-const-button-no)
  (define QT_BUTTON_RESET    ffi-qt-const-button-reset)
  (define QT_BUTTON_HELP     ffi-qt-const-button-help)
  (define QT_BUTTON_SAVE     ffi-qt-const-button-save)
  (define QT_BUTTON_DISCARD  ffi-qt-const-button-discard)

  (define QT_BUTTON_ROLE_INVALID      ffi-qt-const-button-role-invalid)
  (define QT_BUTTON_ROLE_ACCEPT       ffi-qt-const-button-role-accept)
  (define QT_BUTTON_ROLE_REJECT       ffi-qt-const-button-role-reject)
  (define QT_BUTTON_ROLE_DESTRUCTIVE  ffi-qt-const-button-role-destructive)
  (define QT_BUTTON_ROLE_ACTION       ffi-qt-const-button-role-action)
  (define QT_BUTTON_ROLE_HELP         ffi-qt-const-button-role-help)
  (define QT_BUTTON_ROLE_YES          ffi-qt-const-button-role-yes)
  (define QT_BUTTON_ROLE_NO           ffi-qt-const-button-role-no)
  (define QT_BUTTON_ROLE_APPLY        ffi-qt-const-button-role-apply)
  (define QT_BUTTON_ROLE_RESET        ffi-qt-const-button-role-reset)

  (define QT_MONDAY    ffi-qt-const-monday)
  (define QT_TUESDAY   ffi-qt-const-tuesday)
  (define QT_WEDNESDAY ffi-qt-const-wednesday)
  (define QT_THURSDAY  ffi-qt-const-thursday)
  (define QT_FRIDAY    ffi-qt-const-friday)
  (define QT_SATURDAY  ffi-qt-const-saturday)
  (define QT_SUNDAY    ffi-qt-const-sunday)

  (define QT_SETTINGS_NATIVE ffi-qt-const-settings-native)
  (define QT_SETTINGS_INI    ffi-qt-const-settings-ini)

  (define QT_COMPLETER_POPUP            ffi-qt-const-completer-popup)
  (define QT_COMPLETER_INLINE           ffi-qt-const-completer-inline)
  (define QT_COMPLETER_UNFILTERED_POPUP ffi-qt-const-completer-unfiltered-popup)

  (define QT_CASE_INSENSITIVE ffi-qt-const-case-insensitive)
  (define QT_CASE_SENSITIVE   ffi-qt-const-case-sensitive)

  (define QT_MATCH_STARTS_WITH ffi-qt-const-match-starts-with)
  (define QT_MATCH_CONTAINS    ffi-qt-const-match-contains)
  (define QT_MATCH_ENDS_WITH   ffi-qt-const-match-ends-with)

  (define QT_VALIDATOR_INVALID      ffi-qt-const-validator-invalid)
  (define QT_VALIDATOR_INTERMEDIATE ffi-qt-const-validator-intermediate)
  (define QT_VALIDATOR_ACCEPTABLE   ffi-qt-const-validator-acceptable)

  (define QT_PLAIN_NO_WRAP     ffi-qt-const-plain-no-wrap)
  (define QT_PLAIN_WIDGET_WRAP ffi-qt-const-plain-widget-wrap)

  (define QT_DELAYED_POPUP     ffi-qt-const-delayed-popup)
  (define QT_MENU_BUTTON_POPUP ffi-qt-const-menu-button-popup)
  (define QT_INSTANT_POPUP     ffi-qt-const-instant-popup)

  (define QT_NO_ARROW    ffi-qt-const-no-arrow)
  (define QT_UP_ARROW    ffi-qt-const-up-arrow)
  (define QT_DOWN_ARROW  ffi-qt-const-down-arrow)
  (define QT_LEFT_ARROW  ffi-qt-const-left-arrow)
  (define QT_RIGHT_ARROW ffi-qt-const-right-arrow)

  (define QT_TOOL_BUTTON_ICON_ONLY        ffi-qt-const-tool-button-icon-only)
  (define QT_TOOL_BUTTON_TEXT_ONLY        ffi-qt-const-tool-button-text-only)
  (define QT_TOOL_BUTTON_TEXT_BESIDE_ICON ffi-qt-const-tool-button-text-beside-icon)
  (define QT_TOOL_BUTTON_TEXT_UNDER_ICON  ffi-qt-const-tool-button-text-under-icon)

  (define QT_SIZE_FIXED             ffi-qt-const-size-fixed)
  (define QT_SIZE_MINIMUM           ffi-qt-const-size-minimum)
  (define QT_SIZE_MINIMUM_EXPANDING ffi-qt-const-size-minimum-expanding)
  (define QT_SIZE_MAXIMUM           ffi-qt-const-size-maximum)
  (define QT_SIZE_PREFERRED         ffi-qt-const-size-preferred)
  (define QT_SIZE_EXPANDING         ffi-qt-const-size-expanding)
  (define QT_SIZE_IGNORED           ffi-qt-const-size-ignored)

  (define QT_ITEM_MOVABLE    ffi-qt-const-item-movable)
  (define QT_ITEM_SELECTABLE ffi-qt-const-item-selectable)
  (define QT_ITEM_FOCUSABLE  ffi-qt-const-item-focusable)

  (define QT_DRAG_NONE        ffi-qt-const-drag-none)
  (define QT_DRAG_SCROLL      ffi-qt-const-drag-scroll)
  (define QT_DRAG_RUBBER_BAND ffi-qt-const-drag-rubber-band)

  (define QT_RENDER_ANTIALIASING     ffi-qt-const-render-antialiasing)
  (define QT_RENDER_SMOOTH_PIXMAP    ffi-qt-const-render-smooth-pixmap)
  (define QT_RENDER_TEXT_ANTIALIASING ffi-qt-const-render-text-antialiasing)

  (define QT_PROCESS_NOT_RUNNING ffi-qt-const-process-not-running)
  (define QT_PROCESS_STARTING    ffi-qt-const-process-starting)
  (define QT_PROCESS_RUNNING     ffi-qt-const-process-running)

  (define QT_MDI_SUBWINDOW ffi-qt-const-mdi-subwindow)
  (define QT_MDI_TABBED    ffi-qt-const-mdi-tabbed)

  (define QT_LCD_DEC     ffi-qt-const-lcd-dec)
  (define QT_LCD_HEX     ffi-qt-const-lcd-hex)
  (define QT_LCD_OCT     ffi-qt-const-lcd-oct)
  (define QT_LCD_BIN     ffi-qt-const-lcd-bin)
  (define QT_LCD_OUTLINE ffi-qt-const-lcd-outline)
  (define QT_LCD_FILLED  ffi-qt-const-lcd-filled)
  (define QT_LCD_FLAT    ffi-qt-const-lcd-flat)

  (define QT_DIR_DIRS              ffi-qt-const-dir-dirs)
  (define QT_DIR_FILES             ffi-qt-const-dir-files)
  (define QT_DIR_HIDDEN            ffi-qt-const-dir-hidden)
  (define QT_DIR_NO_DOT_AND_DOT_DOT ffi-qt-const-dir-no-dot-and-dot-dot)

  (define QT_CURSOR_NO_MOVE        ffi-qt-const-cursor-no-move)
  (define QT_CURSOR_START          ffi-qt-const-cursor-start)
  (define QT_CURSOR_UP             ffi-qt-const-cursor-up)
  (define QT_CURSOR_START_OF_LINE  ffi-qt-const-cursor-start-of-line)
  (define QT_CURSOR_START_OF_BLOCK ffi-qt-const-cursor-start-of-block)
  (define QT_CURSOR_PREVIOUS_CHAR  ffi-qt-const-cursor-previous-char)
  (define QT_CURSOR_PREVIOUS_BLOCK ffi-qt-const-cursor-previous-block)
  (define QT_CURSOR_END_OF_LINE    ffi-qt-const-cursor-end-of-line)
  (define QT_CURSOR_END_OF_BLOCK   ffi-qt-const-cursor-end-of-block)
  (define QT_CURSOR_NEXT_CHAR      ffi-qt-const-cursor-next-char)
  (define QT_CURSOR_NEXT_BLOCK     ffi-qt-const-cursor-next-block)
  (define QT_CURSOR_END            ffi-qt-const-cursor-end)
  (define QT_CURSOR_DOWN           ffi-qt-const-cursor-down)
  (define QT_CURSOR_LEFT           ffi-qt-const-cursor-left)
  (define QT_CURSOR_WORD_LEFT      ffi-qt-const-cursor-word-left)
  (define QT_CURSOR_NEXT_WORD      ffi-qt-const-cursor-next-word)
  (define QT_CURSOR_RIGHT          ffi-qt-const-cursor-right)
  (define QT_CURSOR_WORD_RIGHT     ffi-qt-const-cursor-word-right)
  (define QT_CURSOR_PREVIOUS_WORD  ffi-qt-const-cursor-previous-word)

  (define QT_MOVE_ANCHOR ffi-qt-const-move-anchor)
  (define QT_KEEP_ANCHOR ffi-qt-const-keep-anchor)

  (define QT_FIND_BACKWARD       ffi-qt-const-find-backward)
  (define QT_FIND_CASE_SENSITIVE ffi-qt-const-find-case-sensitive)
  (define QT_FIND_WHOLE_WORDS    ffi-qt-const-find-whole-words)

  (define QT_DOCK_LEFT   ffi-qt-const-dock-left)
  (define QT_DOCK_RIGHT  ffi-qt-const-dock-right)
  (define QT_DOCK_TOP    ffi-qt-const-dock-top)
  (define QT_DOCK_BOTTOM ffi-qt-const-dock-bottom)

  (define QT_TRAY_NO_ICON     ffi-qt-const-tray-no-icon)
  (define QT_TRAY_INFORMATION ffi-qt-const-tray-information)
  (define QT_TRAY_WARNING     ffi-qt-const-tray-warning)
  (define QT_TRAY_CRITICAL    ffi-qt-const-tray-critical)

  (define QT_KEY_ESCAPE    ffi-qt-const-key-escape)
  (define QT_KEY_TAB       ffi-qt-const-key-tab)
  (define QT_KEY_BACKTAB   ffi-qt-const-key-backtab)
  (define QT_KEY_BACKSPACE ffi-qt-const-key-backspace)
  (define QT_KEY_RETURN    ffi-qt-const-key-return)
  (define QT_KEY_ENTER     ffi-qt-const-key-enter)
  (define QT_KEY_INSERT    ffi-qt-const-key-insert)
  (define QT_KEY_DELETE    ffi-qt-const-key-delete)
  (define QT_KEY_PAUSE     ffi-qt-const-key-pause)
  (define QT_KEY_HOME      ffi-qt-const-key-home)
  (define QT_KEY_END       ffi-qt-const-key-end)
  (define QT_KEY_LEFT      ffi-qt-const-key-left)
  (define QT_KEY_UP        ffi-qt-const-key-up)
  (define QT_KEY_RIGHT     ffi-qt-const-key-right)
  (define QT_KEY_DOWN      ffi-qt-const-key-down)
  (define QT_KEY_PAGE_UP   ffi-qt-const-key-page-up)
  (define QT_KEY_PAGE_DOWN ffi-qt-const-key-page-down)
  (define QT_KEY_F1        ffi-qt-const-key-f1)
  (define QT_KEY_F2        ffi-qt-const-key-f2)
  (define QT_KEY_F3        ffi-qt-const-key-f3)
  (define QT_KEY_F4        ffi-qt-const-key-f4)
  (define QT_KEY_F5        ffi-qt-const-key-f5)
  (define QT_KEY_F6        ffi-qt-const-key-f6)
  (define QT_KEY_F7        ffi-qt-const-key-f7)
  (define QT_KEY_F8        ffi-qt-const-key-f8)
  (define QT_KEY_F9        ffi-qt-const-key-f9)
  (define QT_KEY_F10       ffi-qt-const-key-f10)
  (define QT_KEY_F11       ffi-qt-const-key-f11)
  (define QT_KEY_F12       ffi-qt-const-key-f12)
  (define QT_KEY_SPACE     ffi-qt-const-key-space)

  (define QT_MOD_NONE    ffi-qt-const-mod-none)
  (define QT_MOD_SHIFT   ffi-qt-const-mod-shift)
  (define QT_MOD_CONTROL ffi-qt-const-mod-control)
  (define QT_MOD_ALT     ffi-qt-const-mod-alt)
  (define QT_MOD_META    ffi-qt-const-mod-meta)

  (define QT_SELECT_NO_SELECTION ffi-qt-const-select-no-selection)
  (define QT_SELECT_SINGLE      ffi-qt-const-select-single)
  (define QT_SELECT_MULTI       ffi-qt-const-select-multi)
  (define QT_SELECT_EXTENDED    ffi-qt-const-select-extended)
  (define QT_SELECT_CONTIGUOUS  ffi-qt-const-select-contiguous)
  (define QT_SELECT_ITEMS       ffi-qt-const-select-items)
  (define QT_SELECT_ROWS        ffi-qt-const-select-rows)
  (define QT_SELECT_COLUMNS     ffi-qt-const-select-columns)

  (define QT_NO_EDIT_TRIGGERS     ffi-qt-const-no-edit-triggers)
  (define QT_EDIT_DOUBLE_CLICK    ffi-qt-const-edit-double-click)
  (define QT_EDIT_SELECTED_CLICK  ffi-qt-const-edit-selected-click)
  (define QT_EDIT_ANY_KEY_PRESSED ffi-qt-const-edit-any-key-pressed)
  (define QT_EDIT_ALL_TRIGGERS    ffi-qt-const-edit-all-triggers)

  (define QT_SORT_ASCENDING  ffi-qt-const-sort-ascending)
  (define QT_SORT_DESCENDING ffi-qt-const-sort-descending)

  (define QT_HEADER_INTERACTIVE        ffi-qt-const-header-interactive)
  (define QT_HEADER_STRETCH            ffi-qt-const-header-stretch)
  (define QT_HEADER_FIXED              ffi-qt-const-header-fixed)
  (define QT_HEADER_RESIZE_TO_CONTENTS ffi-qt-const-header-resize-to-contents)

  (define QT_UNCHECKED         ffi-qt-const-unchecked)
  (define QT_PARTIALLY_CHECKED ffi-qt-const-partially-checked)
  (define QT_CHECKED           ffi-qt-const-checked)

  (define QT_FLOW_TOP_TO_BOTTOM ffi-qt-const-flow-top-to-bottom)
  (define QT_FLOW_LEFT_TO_RIGHT ffi-qt-const-flow-left-to-right)

) ;; end library
