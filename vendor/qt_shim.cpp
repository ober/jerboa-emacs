#include "qt_shim.h"

#include <QAccessible>
#include <QApplication>
#include <QMainWindow>
#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QFont>
#include <QLineEdit>
#include <QCheckBox>
#include <QComboBox>
#include <QTextEdit>
#include <QSpinBox>
#include <QDialog>
#include <QMessageBox>
#include <QFileDialog>
#include <QMenuBar>
#include <QMenu>
#include <QAction>
#include <QToolBar>
#include <QStatusBar>
#include <QKeySequence>
#include <QListWidget>
#include <QListWidgetItem>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QTabWidget>
#include <QProgressBar>
#include <QSlider>
#include <QGridLayout>
#include <QTimer>
#include <QClipboard>
#include <QTreeWidget>
#include <QTreeWidgetItem>
#include <QHeaderView>
#include <QScrollArea>
#include <QSplitter>
#include <QEvent>
#include <QKeyEvent>
#include <QPixmap>
#include <QIcon>
#include <QRadioButton>
#include <QButtonGroup>
#include <QGroupBox>
#include <QFontDialog>
#include <QColorDialog>
#include <QColor>
#include <QStackedWidget>
#include <QSyntaxHighlighter>
#include <QRegularExpression>
#include <QDockWidget>
#include <QSystemTrayIcon>
#include <QPainter>
#include <QDrag>
#include <QMimeData>
#include <QDropEvent>
#include <QDragEnterEvent>
#include <QDoubleSpinBox>
#include <QDateEdit>
#include <QTimeEdit>
#include <QFrame>
#include <QProgressDialog>
#include <QInputDialog>
#include <QFormLayout>
#include <QShortcut>
#include <QTextBrowser>
#include <QDialogButtonBox>
#include <QCalendarWidget>
#include <QSettings>
#include <QCompleter>
#include <QStringListModel>
#include <QToolTip>
#include <QWhatsThis>
#include <QStandardItemModel>
#include <QStandardItem>
#include <QSortFilterProxyModel>
#include <QListView>
#include <QTableView>
#include <QTreeView>
#include <QItemSelectionModel>
#include <QRegularExpression>
#include <QPlainTextEdit>
#include <QToolButton>
#include <QIntValidator>
#include <QDoubleValidator>
#include <QRegularExpressionValidator>
#include <QSizePolicy>
#include <QBoxLayout>
#include <QProcess>
#include <QWizard>
#include <QWizardPage>
#include <QMdiArea>
#include <QMdiSubWindow>
#include <QDial>
#include <QLCDNumber>
#include <QToolBox>
#include <QUndoStack>
#include <QUndoCommand>
#include <QScrollBar>
#include <QCursor>
#include <QTextBlock>
#include <QTextDocument>
#include <QFileSystemModel>
#include <QGraphicsScene>
#include <QGraphicsView>
#include <QGraphicsRectItem>
#include <QGraphicsEllipseItem>
#include <QGraphicsLineItem>
#include <QGraphicsTextItem>
#include <QGraphicsPixmapItem>
#include <string>
#include <cstdio>
#include <unordered_map>
#include <sys/wait.h>
#include <signal.h>
#include <QThread>
#include <QMetaObject>
#include <QCoreApplication>
#include <functional>
#include <atomic>
#include <pthread.h>
#include <semaphore.h>
#include <time.h>

// Chez Scheme SMP thread activation — declared in the running Scheme process.
// Deactivating a thread before a blocking foreign call tells GC that the
// thread is not touching the Scheme heap, so stop-the-world GC can proceed
// without waiting for it.  Must reactivate before any Scheme heap access.
// Only available / needed when compiled for a Chez-based build (JEMACS_CHEZ_SMP).
#ifdef JEMACS_CHEZ_SMP
extern "C" int  Sactivate_thread(void);
extern "C" void Sdeactivate_thread(void);
#endif

// ============================================================
// Verbose logging — enabled via qt_verbose_log_enable(path).
// Logs every BlockingQueuedConnection dispatch and explicit
// qt_verbose_log() calls to a file, for hang diagnosis.
// Placed before the SMP section so vlog_bqc_enter/exit are
// visible to the QT_VOID/QT_RETURN macros that follow.
// ============================================================
static FILE*              s_vlog       = nullptr;
static std::atomic<bool>  s_vlog_on    { false };
// Cached Qt thread pointer for vlog_write — set by qt_verbose_log_note_qt_thread().
static pthread_t          s_vlog_qt_pthread = 0;

// Write one timestamped line to the verbose log.
// Uses clock_gettime(CLOCK_MONOTONIC) for microsecond timestamps.
static void vlog_write(const char* prefix, const char* msg) {
    if (!s_vlog_on.load(std::memory_order_relaxed)) return;
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    pthread_t self = pthread_self();
    int on_qt = (s_vlog_qt_pthread && pthread_equal(self, s_vlog_qt_pthread)) ? 1 : 0;
    fprintf(s_vlog, "[%ld.%06ld] [t%lu%s] %s%s\n",
            (long)ts.tv_sec, (long)(ts.tv_nsec / 1000),
            (unsigned long)self, on_qt ? "/QT" : "",
            prefix, msg);
    fflush(s_vlog);
}

extern "C" void qt_verbose_log_enable(const char* path) {
    if (s_vlog) { fclose(s_vlog); s_vlog = nullptr; }
    s_vlog = fopen(path, "a");
    if (s_vlog) {
        s_vlog_on.store(true, std::memory_order_release);
        vlog_write("VERBOSE ", "qt_shim verbose logging enabled");
    }
}

// Called once the Qt thread starts so we can annotate "[t.../QT]" in logs.
extern "C" void qt_verbose_log_note_qt_thread(void) {
    s_vlog_qt_pthread = pthread_self();
    vlog_write("QT-THREAD ", "Qt event thread identified");
}

extern "C" void qt_verbose_log(const char* msg) {
    vlog_write("", msg);
}

static void vlog_bqc_enter(const char* fn) {
    vlog_write("BQC-ENTER ", fn);
}
static void vlog_bqc_exit(const char* fn) {
    vlog_write("BQC-EXIT  ", fn);
}

// ============================================================
// Crash reporter — FFI call ring buffer + SIGSEGV handler
// ============================================================

#include <fcntl.h>
#include <unistd.h>

// execinfo.h (backtrace) is not available on musl (Alpine static builds).
// Guard with __GLIBC__ so the crash reporter still works without backtraces.
#ifdef __GLIBC__
#include <execinfo.h>
#define HAVE_BACKTRACE 1
#else
#define HAVE_BACKTRACE 0
#endif

#define CRASH_RING_SIZE 64

static struct crash_ring_entry {
    const char* func_name;
    int         entering;  // 1 = enter, 0 = exit
    uint64_t    timestamp_ns;
} s_crash_ring[CRASH_RING_SIZE];

static std::atomic<int> s_crash_ring_idx{0};

static inline uint64_t crash_now_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static inline void crash_ring_push(const char* fn, int entering) {
    int idx = s_crash_ring_idx.fetch_add(1, std::memory_order_relaxed) % CRASH_RING_SIZE;
    s_crash_ring[idx].func_name    = fn;
    s_crash_ring[idx].entering     = entering;
    s_crash_ring[idx].timestamp_ns = crash_now_ns();
}

// Async-signal-safe integer-to-string (decimal).
// Returns number of chars written (not including NUL).
static int safe_itoa(char* buf, int buflen, long val) {
    if (buflen <= 0) return 0;
    char tmp[24];
    int neg = 0, len = 0;
    unsigned long uval;
    if (val < 0) { neg = 1; uval = (unsigned long)(-(val + 1)) + 1; }
    else         { uval = (unsigned long)val; }
    if (uval == 0) { tmp[len++] = '0'; }
    else { while (uval > 0 && len < (int)sizeof(tmp)) { tmp[len++] = '0' + (char)(uval % 10); uval /= 10; } }
    int total = neg + len;
    if (total >= buflen) total = buflen - 1;
    int pos = 0;
    if (neg && pos < total) buf[pos++] = '-';
    for (int i = len - 1; i >= 0 && pos < total; i--) buf[pos++] = tmp[i];
    buf[pos] = '\0';
    return pos;
}

// Async-signal-safe hex formatter (no "0x" prefix).
static int safe_hex(char* buf, int buflen, unsigned long val) {
    if (buflen <= 0) return 0;
    static const char hexchars[] = "0123456789abcdef";
    char tmp[20];
    int len = 0;
    if (val == 0) { tmp[len++] = '0'; }
    else { while (val > 0 && len < (int)sizeof(tmp)) { tmp[len++] = hexchars[val & 0xf]; val >>= 4; } }
    int total = (len < buflen - 1) ? len : buflen - 1;
    int pos = 0;
    for (int i = len - 1; i >= 0 && pos < total; i--) buf[pos++] = tmp[i];
    buf[pos] = '\0';
    return pos;
}

// Cached crash log path — set once at install time (not in signal handler).
static char s_crash_log_path[512] = "";

// Async-signal-safe helper: write a C string to fd.
static inline void safe_write_str(int fd, const char* s) {
    if (!s) return;
    int len = 0;
    while (s[len]) len++;
    (void)write(fd, s, len);
}

static void crash_write_report(int sig, siginfo_t* si) {
    char numbuf[32];

    // Write to crash log file
    int fd = open(s_crash_log_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) fd = STDERR_FILENO;  // fallback to stderr

    safe_write_str(fd, "=== JEMACS CRASH REPORT ===\n");
    safe_write_str(fd, "Signal: ");
    safe_itoa(numbuf, sizeof(numbuf), (long)sig);
    safe_write_str(fd, numbuf);
    if (sig == SIGSEGV) safe_write_str(fd, " (SIGSEGV)");
    else if (sig == SIGBUS) safe_write_str(fd, " (SIGBUS)");
    else if (sig == SIGABRT) safe_write_str(fd, " (SIGABRT)");
    safe_write_str(fd, "\n");

    if (si) {
        safe_write_str(fd, "Faulting address: 0x");
        safe_hex(numbuf, sizeof(numbuf), (unsigned long)si->si_addr);
        safe_write_str(fd, numbuf);
        safe_write_str(fd, "\n");
        safe_write_str(fd, "Signal code: ");
        safe_itoa(numbuf, sizeof(numbuf), (long)si->si_code);
        safe_write_str(fd, numbuf);
        safe_write_str(fd, "\n");
    }

    safe_write_str(fd, "\n--- FFI Call Ring Buffer (oldest → newest) ---\n");
    int head = s_crash_ring_idx.load(std::memory_order_relaxed);
    int count = (head < CRASH_RING_SIZE) ? head : CRASH_RING_SIZE;
    int start = (head < CRASH_RING_SIZE) ? 0 : (head % CRASH_RING_SIZE);
    for (int i = 0; i < count; i++) {
        int idx = (start + i) % CRASH_RING_SIZE;
        const struct crash_ring_entry* e = &s_crash_ring[idx];
        if (!e->func_name) continue;

        safe_write_str(fd, "  [");
        safe_itoa(numbuf, sizeof(numbuf), (long)i);
        safe_write_str(fd, numbuf);
        safe_write_str(fd, "] ");
        safe_write_str(fd, e->entering ? "ENTER " : "EXIT  ");
        safe_write_str(fd, e->func_name);
        safe_write_str(fd, " @");
        // Write timestamp in seconds.nanoseconds
        uint64_t ts = e->timestamp_ns;
        safe_itoa(numbuf, sizeof(numbuf), (long)(ts / 1000000000ULL));
        safe_write_str(fd, numbuf);
        safe_write_str(fd, ".");
        // Pad nanoseconds to 9 digits
        long ns = (long)(ts % 1000000000ULL);
        char nsbuf[16];
        safe_itoa(nsbuf, sizeof(nsbuf), ns);
        int nslen = 0; while (nsbuf[nslen]) nslen++;
        for (int p = 0; p < 9 - nslen; p++) safe_write_str(fd, "0");
        safe_write_str(fd, nsbuf);
        safe_write_str(fd, "\n");
    }

    safe_write_str(fd, "\n--- Backtrace ---\n");
#if HAVE_BACKTRACE
    void* bt_frames[64];
    int bt_size = backtrace(bt_frames, 64);
    backtrace_symbols_fd(bt_frames, bt_size, fd);
#else
    safe_write_str(fd, "(backtrace not available — musl build)\n");
#endif
    safe_write_str(fd, "\n=== END CRASH REPORT ===\n");

    // Also dump to stderr if we wrote to a file
    if (fd != STDERR_FILENO) {
        close(fd);
        safe_write_str(STDERR_FILENO, "\n[jemacs] CRASH — report written to ");
        safe_write_str(STDERR_FILENO, s_crash_log_path);
        safe_write_str(STDERR_FILENO, "\n");

        safe_write_str(STDERR_FILENO, "--- Backtrace ---\n");
#if HAVE_BACKTRACE
        backtrace_symbols_fd(bt_frames, bt_size, STDERR_FILENO);
#else
        safe_write_str(STDERR_FILENO, "(backtrace not available — musl build)\n");
#endif
    }
}

static void segv_handler(int sig, siginfo_t* si, void* ctx) {
    (void)ctx;
    crash_write_report(sig, si);
    // Re-raise with default handler for core dump / gdb attach
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_DFL;
    sigaction(sig, &sa, nullptr);
    raise(sig);
}

static void crash_reporter_install() {
    // Cache crash log path (HOME may not be available in signal handler context)
    const char* home = getenv("HOME");
    if (home) {
        int pos = 0;
        while (home[pos] && pos < (int)sizeof(s_crash_log_path) - 24) {
            s_crash_log_path[pos] = home[pos];
            pos++;
        }
        const char* suffix = "/.jemacs-crash.log";
        for (int i = 0; suffix[i] && pos < (int)sizeof(s_crash_log_path) - 1; i++)
            s_crash_log_path[pos++] = suffix[i];
        s_crash_log_path[pos] = '\0';
    } else {
        // Fallback: write to /tmp
        const char* fallback = "/tmp/jemacs-crash.log";
        int pos = 0;
        while (fallback[pos] && pos < (int)sizeof(s_crash_log_path) - 1) {
            s_crash_log_path[pos] = fallback[pos];
            pos++;
        }
        s_crash_log_path[pos] = '\0';
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = segv_handler;
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;  // one-shot
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, nullptr);
    sigaction(SIGBUS,  &sa, nullptr);
    sigaction(SIGABRT, &sa, nullptr);
}

// Exported accessor for crash log path.
extern "C" const char* qt_crash_log_path(void) {
    return s_crash_log_path;
}

// Exported installer (also called internally from qt_application_create).
extern "C" void qt_crash_reporter_install(void) {
    crash_reporter_install();
}

// Null-pointer guard macros (H1): return safely instead of crashing on nullptr.
// Use QT_NULL_CHECK_VOID for void functions, QT_NULL_CHECK_RET for returning ones.
#define QT_NULL_CHECK_VOID(ptr) do { if (!(ptr)) return; } while(0)
#define QT_NULL_CHECK_RET(ptr, val) do { if (!(ptr)) return (val); } while(0)

// Storage for argc/argv (Qt requires stable pointers for QApplication lifetime)
static int    s_argc = 1;
static char   s_arg0[] = "jerboa-qt";
static char*  s_argv[] = { s_arg0, nullptr };

// ============================================================
// SMP Thread-safety dispatch infrastructure
//
// Gambit's M:N scheduler can migrate green threads between OS
// threads at heartbeat preemption points.  Qt requires ALL widget
// operations on the OS thread where QApplication was created.
//
// Primary defense: GAMBCOPT=,-:p1 (single OS processor) ensures
// is_qt_main_thread() always returns true → zero overhead.
//
// Defense-in-depth: when running with multiple OS processors,
// QT_VOID / QT_RETURN / QT_RETURN_STRING marshal the call to
// the Qt main thread via BlockingQueuedConnection.
// ============================================================

// ============================================================
// Qt runs on a dedicated pthread, never on a Gambit VP.
//
// Gambit's M:N SMP scheduler freely migrates green threads between
// OS threads (VPs) at heartbeat preemption points.  Qt requires that
// QApplication::create(), all widget operations, and exec() all run
// on the SAME OS thread.  Running Qt on a dedicated pthread that
// Gambit never touches solves this completely.
//
// qt_application_create()  → spawns g_qt_thread, waits for ready
// qt_application_exec()    → pthread_join (waits until Qt quits)
// All other Qt calls       → BlockingQueuedConnection to g_qt_thread
// ============================================================

// The Qt thread (a dedicated pthread, never a Gambit VP).
static pthread_t     g_qt_thread;
static QThread*      g_qt_main_thread = nullptr;

// Semaphore: qt_application_create() blocks until Qt is ready.
static sem_t         g_qt_ready_sem;

// Set to true once the Qt event loop is running.
// Required for BlockingQueuedConnection to work — there must be a
// running event loop on the target thread to process queued events.
static std::atomic<bool> g_event_loop_running{false};

static inline bool is_qt_main_thread() {
    return !g_qt_main_thread ||
           QThread::currentThread() == g_qt_main_thread;
}

// Dispatch a void body to the Qt main thread.
// If already on Qt thread: calls directly (zero overhead).
// Otherwise: marshals via BlockingQueuedConnection with verbose logging.
#ifdef JEMACS_CHEZ_SMP
#define QT_VOID(...) do {                                           \
    crash_ring_push(__func__, 1);                                   \
    if (is_qt_main_thread()) { __VA_ARGS__; }                      \
    else {                                                          \
        vlog_bqc_enter(__func__);                                   \
        Sdeactivate_thread();                                       \
        QMetaObject::invokeMethod(                                  \
            QCoreApplication::instance(),                           \
            [=]() { __VA_ARGS__; },                                \
            Qt::BlockingQueuedConnection);                          \
        Sactivate_thread();                                         \
        vlog_bqc_exit(__func__);                                    \
    }                                                               \
    crash_ring_push(__func__, 0);                                   \
} while(0)
#else
#define QT_VOID(...) do {                                           \
    crash_ring_push(__func__, 1);                                   \
    if (is_qt_main_thread()) { __VA_ARGS__; }                      \
    else {                                                          \
        vlog_bqc_enter(__func__);                                   \
        QMetaObject::invokeMethod(                                  \
            QCoreApplication::instance(),                           \
            [=]() { __VA_ARGS__; },                                \
            Qt::BlockingQueuedConnection);                          \
        vlog_bqc_exit(__func__);                                    \
    }                                                               \
    crash_ring_push(__func__, 0);                                   \
} while(0)
#endif

// Dispatch a function returning a value.
#ifdef JEMACS_CHEZ_SMP
#define QT_RETURN(type, expr) do {                                  \
    crash_ring_push(__func__, 1);                                   \
    if (is_qt_main_thread()) {                                      \
        type _r = (expr);                                           \
        crash_ring_push(__func__, 0);                               \
        return _r;                                                  \
    }                                                               \
    vlog_bqc_enter(__func__);                                       \
    type _result{};                                                 \
    Sdeactivate_thread();                                           \
    QMetaObject::invokeMethod(                                      \
        QCoreApplication::instance(),                               \
        [&]() { _result = (expr); },                               \
        Qt::BlockingQueuedConnection);                              \
    Sactivate_thread();                                             \
    vlog_bqc_exit(__func__);                                        \
    crash_ring_push(__func__, 0);                                   \
    return _result;                                                 \
} while(0)
#else
#define QT_RETURN(type, expr) do {                                  \
    crash_ring_push(__func__, 1);                                   \
    if (is_qt_main_thread()) {                                      \
        type _r = (expr);                                           \
        crash_ring_push(__func__, 0);                               \
        return _r;                                                  \
    }                                                               \
    vlog_bqc_enter(__func__);                                       \
    type _result{};                                                 \
    QMetaObject::invokeMethod(                                      \
        QCoreApplication::instance(),                               \
        [&]() { _result = (expr); },                               \
        Qt::BlockingQueuedConnection);                              \
    vlog_bqc_exit(__func__);                                        \
    crash_ring_push(__func__, 0);                                   \
    return _result;                                                 \
} while(0)
#endif

// Dispatch a function returning const char* via s_return_buf.
#ifdef JEMACS_CHEZ_SMP
#define QT_RETURN_STRING(expr) do {                                 \
    crash_ring_push(__func__, 1);                                   \
    if (is_qt_main_thread()) {                                      \
        s_return_buf = (expr);                                      \
        crash_ring_push(__func__, 0);                               \
        return s_return_buf.c_str();                                \
    }                                                               \
    vlog_bqc_enter(__func__);                                       \
    std::string _str_result;                                        \
    Sdeactivate_thread();                                           \
    QMetaObject::invokeMethod(                                      \
        QCoreApplication::instance(),                               \
        [&]() { _str_result = (expr); },                           \
        Qt::BlockingQueuedConnection);                              \
    Sactivate_thread();                                             \
    s_return_buf = std::move(_str_result);                         \
    vlog_bqc_exit(__func__);                                        \
    crash_ring_push(__func__, 0);                                   \
    return s_return_buf.c_str();                                    \
} while(0)
#else
#define QT_RETURN_STRING(expr) do {                                 \
    crash_ring_push(__func__, 1);                                   \
    if (is_qt_main_thread()) {                                      \
        s_return_buf = (expr);                                      \
        crash_ring_push(__func__, 0);                               \
        return s_return_buf.c_str();                                \
    }                                                               \
    vlog_bqc_enter(__func__);                                       \
    std::string _str_result;                                        \
    QMetaObject::invokeMethod(                                      \
        QCoreApplication::instance(),                               \
        [&]() { _str_result = (expr); },                           \
        Qt::BlockingQueuedConnection);                              \
    s_return_buf = std::move(_str_result);                         \
    vlog_bqc_exit(__func__);                                        \
    crash_ring_push(__func__, 0);                                   \
    return s_return_buf.c_str();                                    \
} while(0)
#endif

// String buffer for returning strings to FFI safely.
// Qt's QString::toUtf8().constData() returns a pointer to a temporary;
// we copy into this buffer so the pointer remains valid until the next call.
// Safe as a regular static because BlockingQueuedConnection serializes all
// cross-thread calls, and same-thread calls are inherently sequential.
static std::string s_return_buf;

// Storage for last key event (separate from s_return_buf).
// These are set and read within a single Qt callback invocation — always
// on the Qt main thread — so regular statics are safe.
static int s_last_key_code = 0;
static int s_last_key_modifiers = 0;
static std::string s_last_key_text;
static int s_last_key_autorepeat = 0;
static QObject* s_last_key_widget = nullptr;  // which widget fired the last key event

// Storage for QInputDialog ok/cancel flag
static bool s_last_input_ok = false;

// Storage for view signal row/col (Phase 12)
static int s_last_view_row = -1;
static int s_last_view_col = -1;

// KeyPressFilter: QObject subclass that intercepts key events.
// No Q_OBJECT macro needed — just overrides the virtual eventFilter method.
// Parented to the widget it filters (auto-destroyed by Qt ownership).
class KeyPressFilter : public QObject {
public:
    KeyPressFilter(QObject* parent, qt_callback_void callback, long callback_id)
        : QObject(parent), m_callback(callback), m_callback_id(callback_id) {}

    bool eventFilter(QObject* obj, QEvent* event) override {
        if (event->type() == QEvent::KeyPress) {
            auto* ke = static_cast<QKeyEvent*>(event);
            s_last_key_code = ke->key();
            s_last_key_modifiers = static_cast<int>(ke->modifiers());
            s_last_key_text = ke->text().toUtf8().toStdString();
            s_last_key_autorepeat = ke->isAutoRepeat() ? 1 : 0;
            s_last_key_widget = obj;
            m_callback(m_callback_id);
        }
        return QObject::eventFilter(obj, event);
    }

private:
    qt_callback_void m_callback;
    long m_callback_id;
};

// ConsumingKeyPressFilter: same as KeyPressFilter but returns true
// for KeyPress events, preventing the widget from handling them.
// Use this for Emacs-style editors where ALL keys are intercepted.
class ConsumingKeyPressFilter : public QObject {
public:
    ConsumingKeyPressFilter(QObject* parent, qt_callback_void callback, long callback_id)
        : QObject(parent), m_callback(callback), m_callback_id(callback_id) {}

    bool eventFilter(QObject* obj, QEvent* event) override {
        if (event->type() == QEvent::KeyPress) {
            auto* ke = static_cast<QKeyEvent*>(event);
            s_last_key_code = ke->key();
            s_last_key_modifiers = static_cast<int>(ke->modifiers());
            s_last_key_text = ke->text().toUtf8().toStdString();
            s_last_key_autorepeat = ke->isAutoRepeat() ? 1 : 0;
            s_last_key_widget = obj;
            m_callback(m_callback_id);
            return true;  // consume the event — widget does NOT see it
        }
        return QObject::eventFilter(obj, event);
    }

private:
    qt_callback_void m_callback;
    long m_callback_id;
};

// ============================================================
// Application lifecycle
// ============================================================

// Thread entry point for the dedicated Qt thread.
// Creates QApplication, signals ready, runs exec(), cleans up.
static void* qt_thread_main(void* arg) {
    (void)arg;
    // Suppress X11 session management.  When the previous process was killed
    // abnormally (crash, SIGKILL), the X session manager records the session
    // and sends a "Die" or "Interact" request on the next launch.  If we don't
    // handle it, the session manager may call QApplication::quit() immediately.
    // Unsetting SESSION_MANAGER prevents Qt from even trying to connect.
    unsetenv("SESSION_MANAGER");
    // The XCB platform plugin is statically linked; Wayland is not.
    // Default to XCB so the binary works on Wayland desktops without
    // needing external plugin .so files.  Users can still override with
    // QT_QPA_PLATFORM=wayland if they have the dynamic plugin available.
    if (!getenv("QT_QPA_PLATFORM")) {
        setenv("QT_QPA_PLATFORM", "xcb", 0);
    }
    // Record THIS thread as the Qt main thread before creating QApplication.
    g_qt_main_thread = QThread::currentThread();
    auto* app = new QApplication(s_argc, s_argv);
    // Disable accessibility to prevent Scintilla assertion crash.
    // See detailed comment in original qt_application_create.
    QAccessible::setActive(false);

    // Record this as the Qt thread for verbose log annotations.
    qt_verbose_log_note_qt_thread();
    // Signal qt_application_create() that Qt is ready AFTER the event loop
    // starts processing events.  BlockingQueuedConnection calls from the
    // Scheme thread require a running event loop — signalling before exec()
    // creates a race where BQC calls arrive before exec() and deadlock.
    g_event_loop_running.store(true, std::memory_order_release);
    QTimer::singleShot(0, [&]() { sem_post(&g_qt_ready_sem); });

    // Run the Qt event loop.  Blocks until QApplication::quit() is called.
    app->exec();

    g_event_loop_running.store(false, std::memory_order_release);
    delete app;
    return nullptr;
}

extern "C" qt_application_t qt_application_create(int argc, char** argv) {
    (void)argc; (void)argv;
    // Install SIGSEGV/SIGBUS/SIGABRT crash reporter before anything else.
    crash_reporter_install();
    // Initialize the ready semaphore.
    sem_init(&g_qt_ready_sem, 0, 0);
    // Start the dedicated Qt thread.
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_create(&g_qt_thread, &attr, qt_thread_main, nullptr);
    pthread_attr_destroy(&attr);
    // Block until the Qt event loop is running and g_qt_main_thread is set.
    sem_wait(&g_qt_ready_sem);
    sem_destroy(&g_qt_ready_sem);
    return QCoreApplication::instance();
}

extern "C" int qt_application_exec(qt_application_t app) {
    // This function intentionally does NOT block.
    //
    // Blocking a Gambit VP in C code (via pthread_join, nanosleep, etc.)
    // causes a stop-the-world GC deadlock: Gambit's GC barrier requires ALL
    // VPs to reach the sync point, but a VP blocked in C can never do so —
    // even with SIGALRM heartbeats, calling pthread_cond_wait from a signal
    // handler is not async-signal-safe.
    //
    // The correct fix: let the Scheme side poll qt_application_is_running()
    // with (thread-sleep! 0.01) in a loop.  thread-sleep! releases the VP,
    // so GC can always complete.  See qt-app-exec! in qt.ss.
    (void)app;
    return 0;
}

extern "C" int qt_application_is_running(void) {
    return g_event_loop_running.load(std::memory_order_acquire) ? 1 : 0;
}

extern "C" void qt_application_quit(qt_application_t app) {
    // QCoreApplication::quit() posts a QuitEvent — thread-safe.
    (void)app;
    QCoreApplication::quit();
}

extern "C" void qt_application_process_events(qt_application_t app) {
    // Must run on Qt thread — use dispatch.
    QT_VOID((void)app; QCoreApplication::processEvents());
}

extern "C" void qt_application_destroy(qt_application_t app) {
    // Qt thread owns the QApplication and deletes it in qt_thread_main.
    // By the time we are called, qt_application_is_running() has returned false
    // (the Scheme polling loop exited), so the Qt thread is finishing cleanup.
    // pthread_join waits for it to fully exit and frees thread resources.
    (void)app;
    pthread_join(g_qt_thread, nullptr);
}

// Expose is_qt_main_thread() to C code (for use by Gerbil trampolines in libqt.ss).
// Returns 1 if the current thread is the Qt main thread, 0 otherwise.
extern "C" int qt_is_main_thread(void) {
    return is_qt_main_thread() ? 1 : 0;
}

// Schedule a callback to run once the Qt event loop starts.
// With the dedicated Qt thread, the event loop is ALREADY running by the
// time qt_application_create() returns.  This function remains for API
// compatibility but simply posts the callback via a 0ms timer.
extern "C" void qt_schedule_init(qt_callback_void callback, long callback_id) {
    QTimer::singleShot(0, [callback, callback_id]() {
        callback(callback_id);
    });
}

// ============================================================
// Widget base
// ============================================================

extern "C" qt_widget_t qt_widget_create(qt_widget_t parent) {
    QT_RETURN(qt_widget_t, new QWidget(static_cast<QWidget*>(parent)));
}

extern "C" void qt_widget_show(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->show());
}

extern "C" void qt_widget_hide(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->hide());
}

extern "C" void qt_widget_close(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->close());
}

extern "C" void qt_widget_set_enabled(qt_widget_t w, int enabled) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setEnabled(enabled != 0));
}

extern "C" int qt_widget_is_enabled(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->isEnabled() ? 1 : 0);
}

extern "C" void qt_widget_set_visible(qt_widget_t w, int visible) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setVisible(visible != 0));
}

extern "C" void qt_widget_set_updates_enabled(qt_widget_t w, int enabled) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setUpdatesEnabled(enabled != 0));
}

extern "C" int qt_widget_is_visible(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->isVisible() ? 1 : 0);
}

extern "C" void qt_widget_set_fixed_size(qt_widget_t w, int width, int height) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setFixedSize(width, height));
}

extern "C" void qt_widget_set_minimum_size(qt_widget_t w, int width, int height) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setMinimumSize(width, height));
}

extern "C" void qt_widget_set_maximum_size(qt_widget_t w, int width, int height) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setMaximumSize(width, height));
}

extern "C" void qt_widget_set_minimum_width(qt_widget_t w, int width) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setMinimumWidth(width));
}

extern "C" void qt_widget_set_minimum_height(qt_widget_t w, int height) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setMinimumHeight(height));
}

extern "C" void qt_widget_set_maximum_width(qt_widget_t w, int width) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setMaximumWidth(width));
}

extern "C" void qt_widget_set_maximum_height(qt_widget_t w, int height) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setMaximumHeight(height));
}

extern "C" void qt_widget_set_cursor(qt_widget_t w, int shape) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setCursor(QCursor(static_cast<Qt::CursorShape>(shape))));
}

extern "C" void qt_widget_unset_cursor(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->unsetCursor());
}

extern "C" void qt_widget_resize(qt_widget_t w, int width, int height) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->resize(width, height));
}

extern "C" void qt_widget_set_style_sheet(qt_widget_t w, const char* css) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setStyleSheet(QString::fromUtf8(css)));
}

extern "C" void qt_widget_set_attribute(qt_widget_t w, int attribute, int on) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setAttribute(
        static_cast<Qt::WidgetAttribute>(attribute), on != 0));
}

extern "C" void qt_widget_set_tooltip(qt_widget_t w, const char* text) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setToolTip(QString::fromUtf8(text)));
}

extern "C" void qt_widget_set_font_size(qt_widget_t w, int size) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(
        QFont font = static_cast<QWidget*>(w)->font();
        font.setPointSize(size);
        static_cast<QWidget*>(w)->setFont(font)
    );
}

// Forward declaration for L1 cleanup
static void qt_cleanup_extra_selections(void* w);

extern "C" void qt_widget_destroy(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);  // H1: null guard
    QT_VOID(
        QWidget* widget = static_cast<QWidget*>(w);
        qt_cleanup_extra_selections(w);  // L1: clean up extra selections
        // Use deleteLater() instead of delete to avoid use-after-free:
        // pending Qt events (resize, paint, focus) may still reference this
        // widget and will crash if processed after synchronous deletion.
        widget->deleteLater()
    );
}

// ============================================================
// Main Window
// ============================================================

extern "C" qt_main_window_t qt_main_window_create(qt_widget_t parent) {
    QT_RETURN(qt_main_window_t, new QMainWindow(static_cast<QWidget*>(parent)));
}

extern "C" void qt_main_window_set_title(qt_main_window_t w, const char* title) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QMainWindow*>(w)->setWindowTitle(QString::fromUtf8(title)));
}

extern "C" void qt_main_window_set_central_widget(qt_main_window_t w, qt_widget_t child) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QMainWindow*>(w)->setCentralWidget(static_cast<QWidget*>(child)));
}

// ============================================================
// Layouts
// ============================================================

extern "C" qt_layout_t qt_vbox_layout_create(qt_widget_t parent) {
    QT_RETURN(qt_layout_t, new QVBoxLayout(static_cast<QWidget*>(parent)));
}

extern "C" qt_layout_t qt_hbox_layout_create(qt_widget_t parent) {
    QT_RETURN(qt_layout_t, new QHBoxLayout(static_cast<QWidget*>(parent)));
}

extern "C" void qt_layout_add_widget(qt_layout_t layout, qt_widget_t widget) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QLayout*>(layout)->addWidget(static_cast<QWidget*>(widget)));
}

extern "C" void qt_layout_add_stretch(qt_layout_t layout, int stretch) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(
        // addStretch is on QBoxLayout, not QLayout
        if (auto* box = dynamic_cast<QBoxLayout*>(static_cast<QLayout*>(layout))) {
        box->addStretch(stretch);
        }
    );
}

extern "C" void qt_layout_set_spacing(qt_layout_t layout, int spacing) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QLayout*>(layout)->setSpacing(spacing));
}

extern "C" void qt_layout_set_margins(qt_layout_t layout, int left, int top,
                                       int right, int bottom) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QLayout*>(layout)->setContentsMargins(left, top, right, bottom));
}

// ============================================================
// Labels
// ============================================================

extern "C" qt_label_t qt_label_create(const char* text, qt_widget_t parent) {
    QT_RETURN(qt_label_t, new QLabel(QString::fromUtf8(text), static_cast<QWidget*>(parent)));
}

extern "C" void qt_label_set_text(qt_label_t l, const char* text) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QLabel*>(l)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_label_text(qt_label_t l) {
    QT_NULL_CHECK_RET(l, "");
    QT_RETURN_STRING(static_cast<QLabel*>(l)->text().toUtf8().toStdString());
}

extern "C" void qt_label_set_alignment(qt_label_t l, int alignment) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QLabel*>(l)->setAlignment(static_cast<Qt::Alignment>(alignment)));
}

extern "C" void qt_label_set_word_wrap(qt_label_t l, int wrap) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QLabel*>(l)->setWordWrap(wrap != 0));
}

// ============================================================
// Push Button
// ============================================================

extern "C" qt_push_button_t qt_push_button_create(const char* text, qt_widget_t parent) {
    QT_RETURN(qt_push_button_t, new QPushButton(QString::fromUtf8(text), static_cast<QWidget*>(parent)));
}

extern "C" void qt_push_button_set_text(qt_push_button_t b, const char* text) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(static_cast<QPushButton*>(b)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_push_button_text(qt_push_button_t b) {
    QT_NULL_CHECK_RET(b, "");
    QT_RETURN_STRING(static_cast<QPushButton*>(b)->text().toUtf8().toStdString());
}

extern "C" void qt_push_button_on_clicked(qt_push_button_t b,
                                          qt_callback_void callback,
                                          long callback_id) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        QObject::connect(static_cast<QPushButton*>(b), &QPushButton::clicked,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

// ============================================================
// Line Edit
// ============================================================

extern "C" qt_line_edit_t qt_line_edit_create(qt_widget_t parent) {
    QT_RETURN(qt_line_edit_t, new QLineEdit(static_cast<QWidget*>(parent)));
}

extern "C" void qt_line_edit_set_text(qt_line_edit_t e, const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QLineEdit*>(e)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_line_edit_text(qt_line_edit_t e) {
    QT_NULL_CHECK_RET(e, "");
    QT_RETURN_STRING(static_cast<QLineEdit*>(e)->text().toUtf8().toStdString());
}

extern "C" void qt_line_edit_set_placeholder(qt_line_edit_t e, const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QLineEdit*>(e)->setPlaceholderText(QString::fromUtf8(text)));
}

extern "C" void qt_line_edit_set_read_only(qt_line_edit_t e, int read_only) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QLineEdit*>(e)->setReadOnly(read_only != 0));
}

extern "C" void qt_line_edit_set_echo_mode(qt_line_edit_t e, int mode) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QLineEdit*>(e)->setEchoMode(static_cast<QLineEdit::EchoMode>(mode)));
}

extern "C" void qt_line_edit_on_text_changed(qt_line_edit_t e,
                                              qt_callback_string callback,
                                              long callback_id) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        QObject::connect(static_cast<QLineEdit*>(e), &QLineEdit::textChanged,
        [callback, callback_id](const QString& text) {
        std::string s = text.toUtf8().toStdString();
        callback(callback_id, s.c_str());
        })
    );
}

extern "C" void qt_line_edit_on_return_pressed(qt_line_edit_t e,
                                                qt_callback_void callback,
                                                long callback_id) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        QObject::connect(static_cast<QLineEdit*>(e), &QLineEdit::returnPressed,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

// ============================================================
// Check Box
// ============================================================

extern "C" qt_check_box_t qt_check_box_create(const char* text, qt_widget_t parent) {
    QT_RETURN(qt_check_box_t, new QCheckBox(QString::fromUtf8(text), static_cast<QWidget*>(parent)));
}

extern "C" void qt_check_box_set_text(qt_check_box_t c, const char* text) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QCheckBox*>(c)->setText(QString::fromUtf8(text)));
}

extern "C" void qt_check_box_set_checked(qt_check_box_t c, int checked) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QCheckBox*>(c)->setChecked(checked != 0));
}

extern "C" int qt_check_box_is_checked(qt_check_box_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QCheckBox*>(c)->isChecked() ? 1 : 0);
}

extern "C" void qt_check_box_on_toggled(qt_check_box_t c,
                                         qt_callback_bool callback,
                                         long callback_id) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        QObject::connect(static_cast<QCheckBox*>(c), &QCheckBox::toggled,
        [callback, callback_id](bool checked) {
        callback(callback_id, checked ? 1 : 0);
        })
    );
}

// ============================================================
// Combo Box
// ============================================================

extern "C" qt_combo_box_t qt_combo_box_create(qt_widget_t parent) {
    QT_RETURN(qt_combo_box_t, new QComboBox(static_cast<QWidget*>(parent)));
}

extern "C" void qt_combo_box_add_item(qt_combo_box_t c, const char* text) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QComboBox*>(c)->addItem(QString::fromUtf8(text)));
}

extern "C" void qt_combo_box_set_current_index(qt_combo_box_t c, int index) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QComboBox*>(c)->setCurrentIndex(index));
}

extern "C" int qt_combo_box_current_index(qt_combo_box_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QComboBox*>(c)->currentIndex());
}

extern "C" const char* qt_combo_box_current_text(qt_combo_box_t c) {
    QT_NULL_CHECK_RET(c, "");
    QT_RETURN_STRING(static_cast<QComboBox*>(c)->currentText().toUtf8().toStdString());
}

extern "C" int qt_combo_box_count(qt_combo_box_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QComboBox*>(c)->count());
}

extern "C" void qt_combo_box_clear(qt_combo_box_t c) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QComboBox*>(c)->clear());
}

extern "C" void qt_combo_box_on_current_index_changed(qt_combo_box_t c,
                                                       qt_callback_int callback,
                                                       long callback_id) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        QObject::connect(static_cast<QComboBox*>(c),
        QOverload<int>::of(&QComboBox::currentIndexChanged),
        [callback, callback_id](int index) {
        callback(callback_id, index);
        })
    );
}

// ============================================================
// Text Edit
// ============================================================

extern "C" qt_text_edit_t qt_text_edit_create(qt_widget_t parent) {
    QT_RETURN(qt_text_edit_t, new QTextEdit(static_cast<QWidget*>(parent)));
}

extern "C" void qt_text_edit_set_text(qt_text_edit_t e, const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QTextEdit*>(e)->setPlainText(QString::fromUtf8(text)));
}

extern "C" const char* qt_text_edit_text(qt_text_edit_t e) {
    QT_NULL_CHECK_RET(e, "");
    QT_RETURN_STRING(static_cast<QTextEdit*>(e)->toPlainText().toUtf8().toStdString());
}

extern "C" void qt_text_edit_set_placeholder(qt_text_edit_t e, const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QTextEdit*>(e)->setPlaceholderText(QString::fromUtf8(text)));
}

extern "C" void qt_text_edit_set_read_only(qt_text_edit_t e, int read_only) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QTextEdit*>(e)->setReadOnly(read_only != 0));
}

extern "C" void qt_text_edit_append(qt_text_edit_t e, const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QTextEdit*>(e)->append(QString::fromUtf8(text)));
}

extern "C" void qt_text_edit_clear(qt_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QTextEdit*>(e)->clear());
}

extern "C" void qt_text_edit_scroll_to_bottom(qt_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* te = static_cast<QTextEdit*>(e);
        auto* sb = te->verticalScrollBar();
        sb->setValue(sb->maximum())
    );
}

extern "C" const char* qt_text_edit_html(qt_text_edit_t e) {
    QT_NULL_CHECK_RET(e, "");
    QT_RETURN_STRING(static_cast<QTextEdit*>(e)->toHtml().toUtf8().toStdString());
}

extern "C" void qt_text_edit_on_text_changed(qt_text_edit_t e,
                                              qt_callback_void callback,
                                              long callback_id) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        QObject::connect(static_cast<QTextEdit*>(e), &QTextEdit::textChanged,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

// ============================================================
// Spin Box
// ============================================================

extern "C" qt_spin_box_t qt_spin_box_create(qt_widget_t parent) {
    QT_RETURN(qt_spin_box_t, new QSpinBox(static_cast<QWidget*>(parent)));
}

extern "C" void qt_spin_box_set_value(qt_spin_box_t s, int value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSpinBox*>(s)->setValue(value));
}

extern "C" int qt_spin_box_value(qt_spin_box_t s) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QSpinBox*>(s)->value());
}

extern "C" void qt_spin_box_set_range(qt_spin_box_t s, int minimum, int maximum) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSpinBox*>(s)->setRange(minimum, maximum));
}

extern "C" void qt_spin_box_set_single_step(qt_spin_box_t s, int step) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSpinBox*>(s)->setSingleStep(step));
}

extern "C" void qt_spin_box_set_prefix(qt_spin_box_t s, const char* prefix) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSpinBox*>(s)->setPrefix(QString::fromUtf8(prefix)));
}

extern "C" void qt_spin_box_set_suffix(qt_spin_box_t s, const char* suffix) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSpinBox*>(s)->setSuffix(QString::fromUtf8(suffix)));
}

extern "C" void qt_spin_box_on_value_changed(qt_spin_box_t s,
                                              qt_callback_int callback,
                                              long callback_id) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        QObject::connect(static_cast<QSpinBox*>(s),
        QOverload<int>::of(&QSpinBox::valueChanged),
        [callback, callback_id](int value) {
        callback(callback_id, value);
        })
    );
}

// ============================================================
// Dialog
// ============================================================

extern "C" qt_dialog_t qt_dialog_create(qt_widget_t parent) {
    QT_RETURN(qt_dialog_t, new QDialog(static_cast<QWidget*>(parent)));
}

extern "C" int qt_dialog_exec(qt_dialog_t d) {
    QT_NULL_CHECK_RET(d, 0);
    QT_RETURN(int, static_cast<QDialog*>(d)->exec());
}

extern "C" void qt_dialog_accept(qt_dialog_t d) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDialog*>(d)->accept());
}

extern "C" void qt_dialog_reject(qt_dialog_t d) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDialog*>(d)->reject());
}

extern "C" void qt_dialog_set_title(qt_dialog_t d, const char* title) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDialog*>(d)->setWindowTitle(QString::fromUtf8(title)));
}

// ============================================================
// Message Box (static convenience)
// ============================================================

extern "C" int qt_message_box_information(qt_widget_t parent,
                                           const char* title, const char* text) {
    QT_NULL_CHECK_RET(parent, 0);
    QT_RETURN(int,
        QMessageBox::information(static_cast<QWidget*>(parent),
        QString::fromUtf8(title),
        QString::fromUtf8(text)));
}

extern "C" int qt_message_box_warning(qt_widget_t parent,
                                       const char* title, const char* text) {
    QT_NULL_CHECK_RET(parent, 0);
    QT_RETURN(int,
        QMessageBox::warning(static_cast<QWidget*>(parent),
        QString::fromUtf8(title),
        QString::fromUtf8(text)));
}

extern "C" int qt_message_box_question(qt_widget_t parent,
                                        const char* title, const char* text) {
    QT_NULL_CHECK_RET(parent, 0);
    QT_RETURN(int,
        QMessageBox::question(static_cast<QWidget*>(parent),
        QString::fromUtf8(title),
        QString::fromUtf8(text)));
}

extern "C" int qt_message_box_critical(qt_widget_t parent,
                                        const char* title, const char* text) {
    QT_NULL_CHECK_RET(parent, 0);
    QT_RETURN(int,
        QMessageBox::critical(static_cast<QWidget*>(parent),
        QString::fromUtf8(title),
        QString::fromUtf8(text)));
}

// ============================================================
// File Dialog (static convenience)
// ============================================================

extern "C" const char* qt_file_dialog_open_file(qt_widget_t parent,
                                                 const char* caption,
                                                 const char* dir,
                                                 const char* filter) {
    QT_NULL_CHECK_RET(parent, "");
    QT_RETURN_STRING(QFileDialog::getOpenFileName( static_cast<QWidget*>(parent), QString::fromUtf8(caption), QString::fromUtf8(dir), QString::fromUtf8(filter)).toUtf8().toStdString());
}

extern "C" const char* qt_file_dialog_save_file(qt_widget_t parent,
                                                 const char* caption,
                                                 const char* dir,
                                                 const char* filter) {
    QT_NULL_CHECK_RET(parent, "");
    QT_RETURN_STRING(QFileDialog::getSaveFileName( static_cast<QWidget*>(parent), QString::fromUtf8(caption), QString::fromUtf8(dir), QString::fromUtf8(filter)).toUtf8().toStdString());
}

extern "C" const char* qt_file_dialog_open_directory(qt_widget_t parent,
                                                      const char* caption,
                                                      const char* dir) {
    QT_NULL_CHECK_RET(parent, "");
    QT_RETURN_STRING(QFileDialog::getExistingDirectory( static_cast<QWidget*>(parent), QString::fromUtf8(caption), QString::fromUtf8(dir)).toUtf8().toStdString());
}

// ============================================================
// Menu Bar
// ============================================================

extern "C" qt_menu_bar_t qt_main_window_menu_bar(qt_main_window_t w) {
    QT_NULL_CHECK_RET(w, nullptr);
    QT_RETURN(qt_menu_bar_t, static_cast<QMainWindow*>(w)->menuBar());
}

// ============================================================
// Menu
// ============================================================

extern "C" qt_menu_t qt_menu_bar_add_menu(qt_menu_bar_t bar, const char* title) {
    QT_NULL_CHECK_RET(bar, nullptr);
    QT_RETURN(qt_menu_t, static_cast<QMenuBar*>(bar)->addMenu(QString::fromUtf8(title)));
}

extern "C" qt_menu_t qt_menu_add_menu(qt_menu_t menu, const char* title) {
    QT_NULL_CHECK_RET(menu, nullptr);
    QT_RETURN(qt_menu_t, static_cast<QMenu*>(menu)->addMenu(QString::fromUtf8(title)));
}

extern "C" void qt_menu_add_action(qt_menu_t menu, qt_action_t action) {
    QT_NULL_CHECK_VOID(menu);
    QT_VOID(static_cast<QMenu*>(menu)->addAction(static_cast<QAction*>(action)));
}

extern "C" void qt_menu_add_separator(qt_menu_t menu) {
    QT_NULL_CHECK_VOID(menu);
    QT_VOID(static_cast<QMenu*>(menu)->addSeparator());
}

// ============================================================
// Action
// ============================================================

extern "C" qt_action_t qt_action_create(const char* text, qt_widget_t parent) {
    QT_RETURN(qt_action_t, new QAction(QString::fromUtf8(text), static_cast<QWidget*>(parent)));
}

extern "C" void qt_action_set_text(qt_action_t a, const char* text) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_action_text(qt_action_t a) {
    QT_NULL_CHECK_RET(a, "");
    QT_RETURN_STRING(static_cast<QAction*>(a)->text().toUtf8().toStdString());
}

extern "C" void qt_action_set_shortcut(qt_action_t a, const char* shortcut) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setShortcut(QKeySequence(QString::fromUtf8(shortcut))));
}

extern "C" void qt_action_set_enabled(qt_action_t a, int enabled) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setEnabled(enabled != 0));
}

extern "C" int qt_action_is_enabled(qt_action_t a) {
    QT_NULL_CHECK_RET(a, 0);
    QT_RETURN(int, static_cast<QAction*>(a)->isEnabled() ? 1 : 0);
}

extern "C" void qt_action_set_checkable(qt_action_t a, int checkable) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setCheckable(checkable != 0));
}

extern "C" int qt_action_is_checkable(qt_action_t a) {
    QT_NULL_CHECK_RET(a, 0);
    QT_RETURN(int, static_cast<QAction*>(a)->isCheckable() ? 1 : 0);
}

extern "C" void qt_action_set_checked(qt_action_t a, int checked) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setChecked(checked != 0));
}

extern "C" int qt_action_is_checked(qt_action_t a) {
    QT_NULL_CHECK_RET(a, 0);
    QT_RETURN(int, static_cast<QAction*>(a)->isChecked() ? 1 : 0);
}

extern "C" void qt_action_set_tooltip(qt_action_t a, const char* text) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setToolTip(QString::fromUtf8(text)));
}

extern "C" void qt_action_set_status_tip(qt_action_t a, const char* text) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(static_cast<QAction*>(a)->setStatusTip(QString::fromUtf8(text)));
}

extern "C" void qt_action_on_triggered(qt_action_t a,
                                        qt_callback_void callback,
                                        long callback_id) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(
        QObject::connect(static_cast<QAction*>(a), &QAction::triggered,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_action_on_toggled(qt_action_t a,
                                      qt_callback_bool callback,
                                      long callback_id) {
    QT_NULL_CHECK_VOID(a);
    QT_VOID(
        QObject::connect(static_cast<QAction*>(a), &QAction::toggled,
        [callback, callback_id](bool checked) {
        callback(callback_id, checked ? 1 : 0);
        })
    );
}

// ============================================================
// Toolbar
// ============================================================

extern "C" qt_toolbar_t qt_toolbar_create(const char* title, qt_widget_t parent) {
    QT_RETURN(qt_toolbar_t, new QToolBar(QString::fromUtf8(title), static_cast<QWidget*>(parent)));
}

extern "C" void qt_main_window_add_toolbar(qt_main_window_t w, qt_toolbar_t tb) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QMainWindow*>(w)->addToolBar(static_cast<QToolBar*>(tb)));
}

extern "C" void qt_toolbar_add_action(qt_toolbar_t tb, qt_action_t action) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBar*>(tb)->addAction(static_cast<QAction*>(action)));
}

extern "C" void qt_toolbar_add_separator(qt_toolbar_t tb) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBar*>(tb)->addSeparator());
}

extern "C" void qt_toolbar_add_widget(qt_toolbar_t tb, qt_widget_t w) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBar*>(tb)->addWidget(static_cast<QWidget*>(w)));
}

extern "C" void qt_toolbar_set_movable(qt_toolbar_t tb, int movable) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBar*>(tb)->setMovable(movable != 0));
}

extern "C" void qt_toolbar_set_icon_size(qt_toolbar_t tb, int width, int height) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBar*>(tb)->setIconSize(QSize(width, height)));
}

// ============================================================
// Status Bar
// ============================================================

extern "C" void qt_main_window_set_status_bar_text(qt_main_window_t w,
                                                     const char* text) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QMainWindow*>(w)->statusBar()->showMessage(QString::fromUtf8(text)));
}

// ============================================================
// List Widget
// ============================================================

extern "C" qt_list_widget_t qt_list_widget_create(qt_widget_t parent) {
    QT_RETURN(qt_list_widget_t, new QListWidget(static_cast<QWidget*>(parent)));
}

extern "C" void qt_list_widget_add_item(qt_list_widget_t l, const char* text) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QListWidget*>(l)->addItem(QString::fromUtf8(text)));
}

extern "C" void qt_list_widget_insert_item(qt_list_widget_t l, int row,
                                            const char* text) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QListWidget*>(l)->insertItem(row, QString::fromUtf8(text)));
}

extern "C" void qt_list_widget_remove_item(qt_list_widget_t l, int row) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(
        auto* list = static_cast<QListWidget*>(l);
        delete list->takeItem(row)
    );
}

extern "C" int qt_list_widget_current_row(qt_list_widget_t l) {
    QT_NULL_CHECK_RET(l, 0);
    QT_RETURN(int, static_cast<QListWidget*>(l)->currentRow());
}

extern "C" void qt_list_widget_set_current_row(qt_list_widget_t l, int row) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QListWidget*>(l)->setCurrentRow(row));
}

extern "C" const char* qt_list_widget_item_text(qt_list_widget_t l, int row) {
    QT_NULL_CHECK_RET(l, "");
    auto* item = static_cast<QListWidget*>(l)->item(row);
    if (item) {
    } else {
        s_return_buf.clear();
    }
    QT_RETURN_STRING(item->text().toUtf8().toStdString());
}

extern "C" int qt_list_widget_count(qt_list_widget_t l) {
    QT_NULL_CHECK_RET(l, 0);
    QT_RETURN(int, static_cast<QListWidget*>(l)->count());
}

extern "C" void qt_list_widget_clear(qt_list_widget_t l) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(static_cast<QListWidget*>(l)->clear());
}

extern "C" void qt_list_widget_set_item_data(qt_list_widget_t l, int row,
                                              const char* data) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(
        auto* item = static_cast<QListWidget*>(l)->item(row);
        if (item) {
        item->setData(Qt::UserRole, QString::fromUtf8(data));
        }
    );
}

extern "C" const char* qt_list_widget_item_data(qt_list_widget_t l, int row) {
    QT_NULL_CHECK_RET(l, "");
    auto* item = static_cast<QListWidget*>(l)->item(row);
    if (item) {
    } else {
        s_return_buf.clear();
    }
    QT_RETURN_STRING(item->data(Qt::UserRole).toString().toUtf8().toStdString());
}

extern "C" void qt_list_widget_on_current_row_changed(qt_list_widget_t l,
                                                       qt_callback_int callback,
                                                       long callback_id) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(
        QObject::connect(static_cast<QListWidget*>(l),
        &QListWidget::currentRowChanged,
        [callback, callback_id](int row) {
        callback(callback_id, row);
        })
    );
}

extern "C" void qt_list_widget_on_item_double_clicked(qt_list_widget_t l,
                                                       qt_callback_int callback,
                                                       long callback_id) {
    QT_NULL_CHECK_VOID(l);
    QT_VOID(
        auto* list = static_cast<QListWidget*>(l);
        QObject::connect(list, &QListWidget::itemDoubleClicked,
        [callback, callback_id, list](QListWidgetItem* item) {
        callback(callback_id, list->row(item));
        })
    );
}

// ============================================================
// Table Widget
// ============================================================

extern "C" qt_table_widget_t qt_table_widget_create(int rows, int cols,
                                                      qt_widget_t parent) {
    QT_RETURN(qt_table_widget_t, new QTableWidget(rows, cols, static_cast<QWidget*>(parent)));
}

extern "C" void qt_table_widget_set_item(qt_table_widget_t t, int row, int col,
                                          const char* text) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        static_cast<QTableWidget*>(t)->setItem(
        row, col, new QTableWidgetItem(QString::fromUtf8(text)))
    );
}

extern "C" const char* qt_table_widget_item_text(qt_table_widget_t t,
                                                   int row, int col) {
    QT_NULL_CHECK_RET(t, "");
    auto* item = static_cast<QTableWidget*>(t)->item(row, col);
    if (item) {
    } else {
        s_return_buf.clear();
    }
    QT_RETURN_STRING(item->text().toUtf8().toStdString());
}

extern "C" void qt_table_widget_set_horizontal_header_item(qt_table_widget_t t,
                                                             int col,
                                                             const char* text) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        static_cast<QTableWidget*>(t)->setHorizontalHeaderItem(
        col, new QTableWidgetItem(QString::fromUtf8(text)))
    );
}

extern "C" void qt_table_widget_set_vertical_header_item(qt_table_widget_t t,
                                                           int row,
                                                           const char* text) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        static_cast<QTableWidget*>(t)->setVerticalHeaderItem(
        row, new QTableWidgetItem(QString::fromUtf8(text)))
    );
}

extern "C" void qt_table_widget_set_row_count(qt_table_widget_t t, int count) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTableWidget*>(t)->setRowCount(count));
}

extern "C" void qt_table_widget_set_column_count(qt_table_widget_t t, int count) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTableWidget*>(t)->setColumnCount(count));
}

extern "C" int qt_table_widget_row_count(qt_table_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTableWidget*>(t)->rowCount());
}

extern "C" int qt_table_widget_column_count(qt_table_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTableWidget*>(t)->columnCount());
}

extern "C" int qt_table_widget_current_row(qt_table_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTableWidget*>(t)->currentRow());
}

extern "C" int qt_table_widget_current_column(qt_table_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTableWidget*>(t)->currentColumn());
}

extern "C" void qt_table_widget_clear(qt_table_widget_t t) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTableWidget*>(t)->clear());
}

extern "C" void qt_table_widget_on_cell_clicked(qt_table_widget_t t,
                                                  qt_callback_void callback,
                                                  long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTableWidget*>(t),
        &QTableWidget::cellClicked,
        [callback, callback_id](int, int) {
        callback(callback_id);
        })
    );
}

// ============================================================
// Tab Widget
// ============================================================

extern "C" qt_tab_widget_t qt_tab_widget_create(qt_widget_t parent) {
    QT_RETURN(qt_tab_widget_t, new QTabWidget(static_cast<QWidget*>(parent)));
}

extern "C" int qt_tab_widget_add_tab(qt_tab_widget_t t, qt_widget_t page,
                                      const char* label) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int,
        static_cast<QTabWidget*>(t)->addTab(
        static_cast<QWidget*>(page), QString::fromUtf8(label)));
}

extern "C" void qt_tab_widget_set_current_index(qt_tab_widget_t t, int index) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTabWidget*>(t)->setCurrentIndex(index));
}

extern "C" int qt_tab_widget_current_index(qt_tab_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTabWidget*>(t)->currentIndex());
}

extern "C" int qt_tab_widget_count(qt_tab_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTabWidget*>(t)->count());
}

extern "C" void qt_tab_widget_set_tab_text(qt_tab_widget_t t, int index,
                                             const char* text) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTabWidget*>(t)->setTabText(index, QString::fromUtf8(text)));
}

extern "C" void qt_tab_widget_on_current_changed(qt_tab_widget_t t,
                                                   qt_callback_int callback,
                                                   long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTabWidget*>(t),
        &QTabWidget::currentChanged,
        [callback, callback_id](int index) {
        callback(callback_id, index);
        })
    );
}

// ============================================================
// Progress Bar
// ============================================================

extern "C" qt_progress_bar_t qt_progress_bar_create(qt_widget_t parent) {
    QT_RETURN(qt_progress_bar_t, new QProgressBar(static_cast<QWidget*>(parent)));
}

extern "C" void qt_progress_bar_set_value(qt_progress_bar_t p, int value) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QProgressBar*>(p)->setValue(value));
}

extern "C" int qt_progress_bar_value(qt_progress_bar_t p) {
    QT_NULL_CHECK_RET(p, 0);
    QT_RETURN(int, static_cast<QProgressBar*>(p)->value());
}

extern "C" void qt_progress_bar_set_range(qt_progress_bar_t p,
                                            int minimum, int maximum) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QProgressBar*>(p)->setRange(minimum, maximum));
}

extern "C" void qt_progress_bar_set_format(qt_progress_bar_t p,
                                             const char* format) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QProgressBar*>(p)->setFormat(QString::fromUtf8(format)));
}

// ============================================================
// Slider
// ============================================================

extern "C" qt_slider_t qt_slider_create(int orientation, qt_widget_t parent) {
    QT_RETURN(qt_slider_t,
        new QSlider(static_cast<Qt::Orientation>(orientation),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_slider_set_value(qt_slider_t s, int value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSlider*>(s)->setValue(value));
}

extern "C" int qt_slider_value(qt_slider_t s) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QSlider*>(s)->value());
}

extern "C" void qt_slider_set_range(qt_slider_t s, int minimum, int maximum) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSlider*>(s)->setRange(minimum, maximum));
}

extern "C" void qt_slider_set_single_step(qt_slider_t s, int step) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSlider*>(s)->setSingleStep(step));
}

extern "C" void qt_slider_set_tick_interval(qt_slider_t s, int interval) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSlider*>(s)->setTickInterval(interval));
}

extern "C" void qt_slider_set_tick_position(qt_slider_t s, int position) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        static_cast<QSlider*>(s)->setTickPosition(
        static_cast<QSlider::TickPosition>(position))
    );
}

extern "C" void qt_slider_on_value_changed(qt_slider_t s,
                                             qt_callback_int callback,
                                             long callback_id) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        QObject::connect(static_cast<QSlider*>(s), &QSlider::valueChanged,
        [callback, callback_id](int value) {
        callback(callback_id, value);
        })
    );
}

// ============================================================
// Grid Layout
// ============================================================

extern "C" qt_layout_t qt_grid_layout_create(qt_widget_t parent) {
    QT_RETURN(qt_layout_t, new QGridLayout(static_cast<QWidget*>(parent)));
}

extern "C" void qt_grid_layout_add_widget(qt_layout_t layout, qt_widget_t widget,
                                           int row, int col,
                                           int row_span, int col_span) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(
        static_cast<QGridLayout*>(layout)->addWidget(
        static_cast<QWidget*>(widget), row, col, row_span, col_span)
    );
}

extern "C" void qt_grid_layout_set_row_stretch(qt_layout_t layout,
                                                int row, int stretch) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QGridLayout*>(layout)->setRowStretch(row, stretch));
}

extern "C" void qt_grid_layout_set_column_stretch(qt_layout_t layout,
                                                    int col, int stretch) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QGridLayout*>(layout)->setColumnStretch(col, stretch));
}

extern "C" void qt_grid_layout_set_row_minimum_height(qt_layout_t layout,
                                                        int row, int height) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QGridLayout*>(layout)->setRowMinimumHeight(row, height));
}

extern "C" void qt_grid_layout_set_column_minimum_width(qt_layout_t layout,
                                                          int col, int width) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QGridLayout*>(layout)->setColumnMinimumWidth(col, width));
}

// ============================================================
// Timer
// ============================================================

extern "C" qt_timer_t qt_timer_create(void) {
    QT_RETURN(qt_timer_t, new QTimer());
}

extern "C" void qt_timer_start(qt_timer_t t, int msec) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTimer*>(t)->start(msec));
}

extern "C" void qt_timer_stop(qt_timer_t t) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTimer*>(t)->stop());
}

extern "C" void qt_timer_set_single_shot(qt_timer_t t, int single_shot) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTimer*>(t)->setSingleShot(single_shot != 0));
}

extern "C" int qt_timer_is_active(qt_timer_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTimer*>(t)->isActive() ? 1 : 0);
}

extern "C" int qt_timer_interval(qt_timer_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTimer*>(t)->interval());
}

extern "C" void qt_timer_set_interval(qt_timer_t t, int msec) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTimer*>(t)->setInterval(msec));
}

extern "C" void qt_timer_on_timeout(qt_timer_t t,
                                     qt_callback_void callback,
                                     long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTimer*>(t), &QTimer::timeout,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_timer_single_shot(int msec,
                                      qt_callback_void callback,
                                      long callback_id) {
    QT_VOID(
        QTimer::singleShot(msec, [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_timer_destroy(qt_timer_t t) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(delete static_cast<QTimer*>(t));
}

// ============================================================
// Clipboard
// ============================================================

extern "C" const char* qt_clipboard_text(qt_application_t app) {
    QT_NULL_CHECK_RET(app, "");
    (void)app;
    QClipboard* cb = QApplication::clipboard();
    QT_RETURN_STRING(cb->text().toUtf8().toStdString());
}

extern "C" void qt_clipboard_set_text(qt_application_t app, const char* text) {
    QT_NULL_CHECK_VOID(app);
    QT_VOID(
        (void)app;
        QApplication::clipboard()->setText(QString::fromUtf8(text))
    );
}

extern "C" void qt_clipboard_on_changed(qt_application_t app,
                                         qt_callback_void callback,
                                         long callback_id) {
    QT_NULL_CHECK_VOID(app);
    QT_VOID(
        (void)app;
        QObject::connect(QApplication::clipboard(), &QClipboard::dataChanged,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

// ============================================================
// Tree Widget
// ============================================================

extern "C" qt_tree_widget_t qt_tree_widget_create(qt_widget_t parent) {
    QT_RETURN(qt_tree_widget_t, new QTreeWidget(static_cast<QWidget*>(parent)));
}

extern "C" void qt_tree_widget_set_column_count(qt_tree_widget_t t, int count) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTreeWidget*>(t)->setColumnCount(count));
}

extern "C" int qt_tree_widget_column_count(qt_tree_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTreeWidget*>(t)->columnCount());
}

extern "C" void qt_tree_widget_set_header_label(qt_tree_widget_t t,
                                                  const char* label) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTreeWidget*>(t)->setHeaderLabel(QString::fromUtf8(label)));
}

extern "C" void qt_tree_widget_set_header_item_text(qt_tree_widget_t t,
                                                      int col,
                                                      const char* text) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        auto* tree = static_cast<QTreeWidget*>(t);
        auto* header = tree->headerItem();
        if (header) {
        header->setText(col, QString::fromUtf8(text));
        }
    );
}

extern "C" void qt_tree_widget_add_top_level_item(qt_tree_widget_t t,
                                                    qt_tree_item_t item) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        static_cast<QTreeWidget*>(t)->addTopLevelItem(
        static_cast<QTreeWidgetItem*>(item))
    );
}

extern "C" int qt_tree_widget_top_level_item_count(qt_tree_widget_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTreeWidget*>(t)->topLevelItemCount());
}

extern "C" qt_tree_item_t qt_tree_widget_top_level_item(qt_tree_widget_t t,
                                                          int index) {
    QT_NULL_CHECK_RET(t, nullptr);
    QT_RETURN(qt_tree_item_t, static_cast<QTreeWidget*>(t)->topLevelItem(index));
}

extern "C" qt_tree_item_t qt_tree_widget_current_item(qt_tree_widget_t t) {
    QT_NULL_CHECK_RET(t, nullptr);
    QT_RETURN(qt_tree_item_t, static_cast<QTreeWidget*>(t)->currentItem());
}

extern "C" void qt_tree_widget_set_current_item(qt_tree_widget_t t,
                                                  qt_tree_item_t item) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        static_cast<QTreeWidget*>(t)->setCurrentItem(
        static_cast<QTreeWidgetItem*>(item))
    );
}

extern "C" void qt_tree_widget_expand_item(qt_tree_widget_t t,
                                             qt_tree_item_t item) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        (void)t;
        static_cast<QTreeWidgetItem*>(item)->setExpanded(true)
    );
}

extern "C" void qt_tree_widget_collapse_item(qt_tree_widget_t t,
                                               qt_tree_item_t item) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        (void)t;
        static_cast<QTreeWidgetItem*>(item)->setExpanded(false)
    );
}

extern "C" void qt_tree_widget_expand_all(qt_tree_widget_t t) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTreeWidget*>(t)->expandAll());
}

extern "C" void qt_tree_widget_collapse_all(qt_tree_widget_t t) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTreeWidget*>(t)->collapseAll());
}

extern "C" void qt_tree_widget_clear(qt_tree_widget_t t) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTreeWidget*>(t)->clear());
}

extern "C" void qt_tree_widget_on_current_item_changed(qt_tree_widget_t t,
                                                         qt_callback_void callback,
                                                         long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTreeWidget*>(t),
        &QTreeWidget::currentItemChanged,
        [callback, callback_id](QTreeWidgetItem*, QTreeWidgetItem*) {
        callback(callback_id);
        })
    );
}

extern "C" void qt_tree_widget_on_item_double_clicked(qt_tree_widget_t t,
                                                        qt_callback_void callback,
                                                        long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTreeWidget*>(t),
        &QTreeWidget::itemDoubleClicked,
        [callback, callback_id](QTreeWidgetItem*, int) {
        callback(callback_id);
        })
    );
}

extern "C" void qt_tree_widget_on_item_expanded(qt_tree_widget_t t,
                                                  qt_callback_void callback,
                                                  long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTreeWidget*>(t),
        &QTreeWidget::itemExpanded,
        [callback, callback_id](QTreeWidgetItem*) {
        callback(callback_id);
        })
    );
}

extern "C" void qt_tree_widget_on_item_collapsed(qt_tree_widget_t t,
                                                   qt_callback_void callback,
                                                   long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTreeWidget*>(t),
        &QTreeWidget::itemCollapsed,
        [callback, callback_id](QTreeWidgetItem*) {
        callback(callback_id);
        })
    );
}

// ============================================================
// Tree Widget Item
// ============================================================

extern "C" qt_tree_item_t qt_tree_item_create(const char* text) {
    QT_RETURN(qt_tree_item_t, new QTreeWidgetItem(QStringList(QString::fromUtf8(text))));
}

extern "C" void qt_tree_item_set_text(qt_tree_item_t item, int col,
                                       const char* text) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QTreeWidgetItem*>(item)->setText(col, QString::fromUtf8(text)));
}

extern "C" const char* qt_tree_item_text(qt_tree_item_t item, int col) {
    QT_NULL_CHECK_RET(item, "");
    QT_RETURN_STRING(static_cast<QTreeWidgetItem*>(item)->text(col).toUtf8().toStdString());
}

extern "C" void qt_tree_item_add_child(qt_tree_item_t parent,
                                        qt_tree_item_t child) {
    QT_NULL_CHECK_VOID(parent);
    QT_VOID(
        static_cast<QTreeWidgetItem*>(parent)->addChild(
        static_cast<QTreeWidgetItem*>(child))
    );
}

extern "C" int qt_tree_item_child_count(qt_tree_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QTreeWidgetItem*>(item)->childCount());
}

extern "C" qt_tree_item_t qt_tree_item_child(qt_tree_item_t item, int index) {
    QT_NULL_CHECK_RET(item, nullptr);
    QT_RETURN(qt_tree_item_t, static_cast<QTreeWidgetItem*>(item)->child(index));
}

extern "C" qt_tree_item_t qt_tree_item_parent(qt_tree_item_t item) {
    QT_NULL_CHECK_RET(item, nullptr);
    QT_RETURN(qt_tree_item_t, static_cast<QTreeWidgetItem*>(item)->parent());
}

extern "C" void qt_tree_item_set_expanded(qt_tree_item_t item, int expanded) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QTreeWidgetItem*>(item)->setExpanded(expanded != 0));
}

extern "C" int qt_tree_item_is_expanded(qt_tree_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QTreeWidgetItem*>(item)->isExpanded() ? 1 : 0);
}

// ============================================================
// App-wide Style Sheet
// ============================================================

extern "C" void qt_application_set_style_sheet(qt_application_t app,
                                                const char* css) {
    QT_VOID(static_cast<QApplication*>(app)->setStyleSheet(QString::fromUtf8(css)));
}

// ============================================================
// Window State Management
// ============================================================

extern "C" void qt_widget_show_minimized(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->showMinimized());
}

extern "C" void qt_widget_show_maximized(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->showMaximized());
}

extern "C" void qt_widget_show_fullscreen(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->showFullScreen());
}

extern "C" void qt_widget_show_normal(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->showNormal());
}

extern "C" int qt_widget_window_state(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<int>(static_cast<QWidget*>(w)->windowState()));
}

extern "C" void qt_widget_move(qt_widget_t w, int x, int y) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->move(x, y));
}

extern "C" int qt_widget_x(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->x());
}

extern "C" int qt_widget_y(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->y());
}

extern "C" int qt_widget_width(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->width());
}

extern "C" int qt_widget_height(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->height());
}

extern "C" void qt_widget_set_focus(qt_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setFocus());
}

// ============================================================
// Scroll Area
// ============================================================

extern "C" qt_scroll_area_t qt_scroll_area_create(qt_widget_t parent) {
    QT_RETURN(qt_scroll_area_t, new QScrollArea(static_cast<QWidget*>(parent)));
}

extern "C" void qt_scroll_area_set_widget(qt_scroll_area_t s, qt_widget_t w) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QScrollArea*>(s)->setWidget(static_cast<QWidget*>(w)));
}

extern "C" void qt_scroll_area_set_widget_resizable(qt_scroll_area_t s,
                                                     int resizable) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QScrollArea*>(s)->setWidgetResizable(resizable != 0));
}

extern "C" void qt_scroll_area_set_horizontal_scrollbar_policy(
    qt_scroll_area_t s, int policy) {
    QT_VOID(
        static_cast<QScrollArea*>(s)->setHorizontalScrollBarPolicy(
        static_cast<Qt::ScrollBarPolicy>(policy))
    );
}

extern "C" void qt_scroll_area_set_vertical_scrollbar_policy(
    qt_scroll_area_t s, int policy) {
    QT_VOID(
        static_cast<QScrollArea*>(s)->setVerticalScrollBarPolicy(
        static_cast<Qt::ScrollBarPolicy>(policy))
    );
}

// ============================================================
// Splitter
// ============================================================

extern "C" qt_splitter_t qt_splitter_create(int orientation,
                                             qt_widget_t parent) {
    QT_RETURN(qt_splitter_t,
        new QSplitter(static_cast<Qt::Orientation>(orientation),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_splitter_add_widget(qt_splitter_t s, qt_widget_t w) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->addWidget(static_cast<QWidget*>(w)));
}

extern "C" void qt_splitter_insert_widget(qt_splitter_t s, int index, qt_widget_t w) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->insertWidget(index, static_cast<QWidget*>(w)));
}

extern "C" int qt_splitter_index_of(qt_splitter_t s, qt_widget_t w) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QSplitter*>(s)->indexOf(static_cast<QWidget*>(w)));
}

extern "C" qt_widget_t qt_splitter_widget(qt_splitter_t s, int index) {
    QT_NULL_CHECK_RET(s, nullptr);
    QT_RETURN(qt_widget_t, static_cast<QSplitter*>(s)->widget(index));
}

extern "C" int qt_splitter_count(qt_splitter_t s) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QSplitter*>(s)->count());
}

extern "C" void qt_splitter_set_sizes_2(qt_splitter_t s, int a, int b) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->setSizes({a, b}));
}

extern "C" void qt_splitter_set_sizes_3(qt_splitter_t s, int a, int b, int c) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->setSizes({a, b, c}));
}

extern "C" void qt_splitter_set_sizes_4(qt_splitter_t s, int a, int b, int c, int d) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->setSizes({a, b, c, d}));
}

extern "C" int qt_splitter_size_at(qt_splitter_t s, int index) {
    QT_NULL_CHECK_RET(s, 0);
    QList<int> sizes = static_cast<QSplitter*>(s)->sizes();
    if (index >= 0 && index < sizes.size())
    QT_RETURN(int, sizes[index]);
    return 0;
}

extern "C" void qt_splitter_set_stretch_factor(qt_splitter_t s, int index,
                                                int stretch) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->setStretchFactor(index, stretch));
}

extern "C" void qt_splitter_set_handle_width(qt_splitter_t s, int width) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->setHandleWidth(width));
}

extern "C" void qt_splitter_set_collapsible(qt_splitter_t s, int index,
                                             int collapsible) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSplitter*>(s)->setCollapsible(index, collapsible != 0));
}

extern "C" int qt_splitter_is_collapsible(qt_splitter_t s, int index) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QSplitter*>(s)->isCollapsible(index) ? 1 : 0);
}

extern "C" void qt_splitter_set_orientation(qt_splitter_t s, int orientation) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        static_cast<QSplitter*>(s)->setOrientation(
        static_cast<Qt::Orientation>(orientation))
    );
}

// ============================================================
// Keyboard Events
// ============================================================

extern "C" void qt_widget_install_key_handler(qt_widget_t w,
                                               qt_callback_void callback,
                                               long callback_id) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(
        auto* widget = static_cast<QWidget*>(w);
        auto* filter = new KeyPressFilter(widget, callback, callback_id);
        widget->installEventFilter(filter)
    );
}

extern "C" void qt_widget_install_key_handler_consuming(qt_widget_t w,
                                                         qt_callback_void callback,
                                                         long callback_id) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(
        auto* widget = static_cast<QWidget*>(w);
        auto* filter = new ConsumingKeyPressFilter(widget, callback, callback_id);
        widget->installEventFilter(filter)
    );
}

extern "C" int qt_last_key_code(void) {
    QT_RETURN(int, s_last_key_code);
}

extern "C" int qt_last_key_modifiers(void) {
    QT_RETURN(int, s_last_key_modifiers);
}

extern "C" const char* qt_last_key_text(void) {
    QT_RETURN(const char*, s_last_key_text.c_str());
}

extern "C" int qt_last_key_autorepeat(void) {
    QT_RETURN(int, s_last_key_autorepeat);
}

// Returns the QObject* (widget pointer) that fired the last key event.
// Lets Chez determine whether a key came from a terminal widget or an editor.
extern "C" void* qt_last_key_widget(void) {
    return s_last_key_widget;
}

extern "C" void qt_send_key_event(qt_widget_t w, int type, int key, int modifiers, const char* text) {
    QT_NULL_CHECK_VOID(w);
    // Capture primitives by value; construct QKeyEvent inside the lambda
    // because QKeyEvent is non-copyable in Qt6.
    int etype_int = type;
    int key_int = key;
    int mods_int = modifiers;
    std::string text_str(text ? text : "");
    QT_VOID(
        QEvent::Type etype = (etype_int == 0) ? QEvent::KeyPress : QEvent::KeyRelease;
        QKeyEvent ev(etype,
                     static_cast<Qt::Key>(key_int),
                     static_cast<Qt::KeyboardModifiers>(mods_int),
                     QString::fromStdString(text_str));
        QApplication::sendEvent(static_cast<QWidget*>(w), &ev)
    );
}

// ============================================================
// Pixmap
// ============================================================

extern "C" qt_pixmap_t qt_pixmap_load(const char* path) {
    auto* pm = new QPixmap(QString::fromUtf8(path));
    QT_RETURN(qt_pixmap_t, pm);
}

extern "C" int qt_pixmap_width(qt_pixmap_t p) {
    QT_NULL_CHECK_RET(p, 0);
    QT_RETURN(int, static_cast<QPixmap*>(p)->width());
}

extern "C" int qt_pixmap_height(qt_pixmap_t p) {
    QT_NULL_CHECK_RET(p, 0);
    QT_RETURN(int, static_cast<QPixmap*>(p)->height());
}

extern "C" int qt_pixmap_is_null(qt_pixmap_t p) {
    QT_NULL_CHECK_RET(p, 0);
    QT_RETURN(int, static_cast<QPixmap*>(p)->isNull() ? 1 : 0);
}

extern "C" qt_pixmap_t qt_pixmap_scaled(qt_pixmap_t p, int w, int h) {
    QT_NULL_CHECK_RET(p, nullptr);
    auto* scaled = new QPixmap(
        static_cast<QPixmap*>(p)->scaled(w, h, Qt::KeepAspectRatio,
                                          Qt::SmoothTransformation));
    QT_RETURN(qt_pixmap_t, scaled);
}

extern "C" void qt_pixmap_destroy(qt_pixmap_t p) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(delete static_cast<QPixmap*>(p));
}

extern "C" int qt_pixmap_save(qt_pixmap_t p, const char* path, const char* format) {
    QT_NULL_CHECK_RET(p, 0);
    QT_RETURN(int, static_cast<QPixmap*>(p)->save(QString::fromUtf8(path), format) ? 1 : 0);
}

extern "C" qt_pixmap_t qt_widget_grab(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, nullptr);
    QT_RETURN(qt_pixmap_t, new QPixmap(static_cast<QWidget*>(w)->grab()));
}

extern "C" void qt_label_set_pixmap(qt_label_t label, qt_pixmap_t pixmap) {
    QT_NULL_CHECK_VOID(label);
    QT_VOID(static_cast<QLabel*>(label)->setPixmap(*static_cast<QPixmap*>(pixmap)));
}

// ============================================================
// Icon
// ============================================================

extern "C" qt_icon_t qt_icon_create(const char* path) {
    QT_RETURN(qt_icon_t, new QIcon(QString::fromUtf8(path)));
}

extern "C" qt_icon_t qt_icon_create_from_pixmap(qt_pixmap_t pixmap) {
    QT_RETURN(qt_icon_t, new QIcon(*static_cast<QPixmap*>(pixmap)));
}

extern "C" int qt_icon_is_null(qt_icon_t icon) {
    QT_NULL_CHECK_RET(icon, 0);
    QT_RETURN(int, static_cast<QIcon*>(icon)->isNull() ? 1 : 0);
}

extern "C" void qt_icon_destroy(qt_icon_t icon) {
    QT_NULL_CHECK_VOID(icon);
    QT_VOID(delete static_cast<QIcon*>(icon));
}

extern "C" void qt_push_button_set_icon(qt_push_button_t button,
                                         qt_icon_t icon) {
    QT_NULL_CHECK_VOID(button);
    QT_VOID(static_cast<QPushButton*>(button)->setIcon(*static_cast<QIcon*>(icon)));
}

extern "C" void qt_action_set_icon(qt_action_t action, qt_icon_t icon) {
    QT_NULL_CHECK_VOID(action);
    QT_VOID(static_cast<QAction*>(action)->setIcon(*static_cast<QIcon*>(icon)));
}

extern "C" void qt_widget_set_window_icon(qt_widget_t widget,
                                           qt_icon_t icon) {
    QT_NULL_CHECK_VOID(widget);
    QT_VOID(static_cast<QWidget*>(widget)->setWindowIcon(*static_cast<QIcon*>(icon)));
}

// ============================================================
// Radio Button
// ============================================================

extern "C" qt_radio_button_t qt_radio_button_create(const char* text,
                                                      qt_widget_t parent) {
    QT_RETURN(qt_radio_button_t,
        new QRadioButton(QString::fromUtf8(text),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_radio_button_set_text(qt_radio_button_t r,
                                          const char* text) {
    QT_NULL_CHECK_VOID(r);
    QT_VOID(static_cast<QRadioButton*>(r)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_radio_button_text(qt_radio_button_t r) {
    QT_NULL_CHECK_RET(r, "");
    QT_RETURN_STRING(static_cast<QRadioButton*>(r)->text().toUtf8().toStdString());
}

extern "C" void qt_radio_button_set_checked(qt_radio_button_t r,
                                             int checked) {
    QT_NULL_CHECK_VOID(r);
    QT_VOID(static_cast<QRadioButton*>(r)->setChecked(checked != 0));
}

extern "C" int qt_radio_button_is_checked(qt_radio_button_t r) {
    QT_NULL_CHECK_RET(r, 0);
    QT_RETURN(int, static_cast<QRadioButton*>(r)->isChecked() ? 1 : 0);
}

extern "C" void qt_radio_button_on_toggled(qt_radio_button_t r,
                                            qt_callback_bool callback,
                                            long callback_id) {
    QT_NULL_CHECK_VOID(r);
    QT_VOID(
        QObject::connect(static_cast<QRadioButton*>(r), &QRadioButton::toggled,
        [callback, callback_id](bool checked) {
        callback(callback_id, checked ? 1 : 0);
        })
    );
}

// ============================================================
// Button Group
// ============================================================

extern "C" qt_button_group_t qt_button_group_create(void) {
    QT_RETURN(qt_button_group_t, new QButtonGroup());
}

extern "C" void qt_button_group_add_button(qt_button_group_t bg,
                                            qt_widget_t button, int id) {
    QT_NULL_CHECK_VOID(bg);
    QT_VOID(
        static_cast<QButtonGroup*>(bg)->addButton(
        static_cast<QAbstractButton*>(button), id)
    );
}

extern "C" void qt_button_group_remove_button(qt_button_group_t bg,
                                               qt_widget_t button) {
    QT_NULL_CHECK_VOID(bg);
    QT_VOID(
        static_cast<QButtonGroup*>(bg)->removeButton(
        static_cast<QAbstractButton*>(button))
    );
}

extern "C" int qt_button_group_checked_id(qt_button_group_t bg) {
    QT_NULL_CHECK_RET(bg, 0);
    QT_RETURN(int, static_cast<QButtonGroup*>(bg)->checkedId());
}

extern "C" void qt_button_group_set_exclusive(qt_button_group_t bg,
                                               int exclusive) {
    QT_NULL_CHECK_VOID(bg);
    QT_VOID(static_cast<QButtonGroup*>(bg)->setExclusive(exclusive != 0));
}

extern "C" int qt_button_group_is_exclusive(qt_button_group_t bg) {
    QT_NULL_CHECK_RET(bg, 0);
    QT_RETURN(int, static_cast<QButtonGroup*>(bg)->exclusive() ? 1 : 0);
}

extern "C" void qt_button_group_on_id_clicked(qt_button_group_t bg,
                                               qt_callback_int callback,
                                               long callback_id) {
    QT_NULL_CHECK_VOID(bg);
    QT_VOID(
        QObject::connect(static_cast<QButtonGroup*>(bg),
        &QButtonGroup::idClicked,
        [callback, callback_id](int id) {
        callback(callback_id, id);
        })
    );
}

extern "C" void qt_button_group_destroy(qt_button_group_t bg) {
    QT_NULL_CHECK_VOID(bg);
    QT_VOID(delete static_cast<QButtonGroup*>(bg));
}

// ============================================================
// Group Box
// ============================================================

extern "C" qt_group_box_t qt_group_box_create(const char* title,
                                               qt_widget_t parent) {
    QT_RETURN(qt_group_box_t,
        new QGroupBox(QString::fromUtf8(title),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_group_box_set_title(qt_group_box_t gb,
                                        const char* title) {
    QT_NULL_CHECK_VOID(gb);
    QT_VOID(static_cast<QGroupBox*>(gb)->setTitle(QString::fromUtf8(title)));
}

extern "C" const char* qt_group_box_title(qt_group_box_t gb) {
    QT_NULL_CHECK_RET(gb, "");
    QT_RETURN_STRING(static_cast<QGroupBox*>(gb)->title().toUtf8().toStdString());
}

extern "C" void qt_group_box_set_checkable(qt_group_box_t gb,
                                            int checkable) {
    QT_NULL_CHECK_VOID(gb);
    QT_VOID(static_cast<QGroupBox*>(gb)->setCheckable(checkable != 0));
}

extern "C" int qt_group_box_is_checkable(qt_group_box_t gb) {
    QT_NULL_CHECK_RET(gb, 0);
    QT_RETURN(int, static_cast<QGroupBox*>(gb)->isCheckable() ? 1 : 0);
}

extern "C" void qt_group_box_set_checked(qt_group_box_t gb, int checked) {
    QT_NULL_CHECK_VOID(gb);
    QT_VOID(static_cast<QGroupBox*>(gb)->setChecked(checked != 0));
}

extern "C" int qt_group_box_is_checked(qt_group_box_t gb) {
    QT_NULL_CHECK_RET(gb, 0);
    QT_RETURN(int, static_cast<QGroupBox*>(gb)->isChecked() ? 1 : 0);
}

extern "C" void qt_group_box_on_toggled(qt_group_box_t gb,
                                         qt_callback_bool callback,
                                         long callback_id) {
    QT_NULL_CHECK_VOID(gb);
    QT_VOID(
        QObject::connect(static_cast<QGroupBox*>(gb), &QGroupBox::toggled,
        [callback, callback_id](bool checked) {
        callback(callback_id, checked ? 1 : 0);
        })
    );
}

// ============================================================
// Phase 8a: Font
// ============================================================

extern "C" qt_font_t qt_font_create(const char* family, int point_size) {
    QT_RETURN(qt_font_t, new QFont(QString::fromUtf8(family), point_size));
}

extern "C" const char* qt_font_family(qt_font_t f) {
    QT_NULL_CHECK_RET(f, "");
    QT_RETURN_STRING(static_cast<QFont*>(f)->family().toUtf8().toStdString());
}

extern "C" int qt_font_point_size(qt_font_t f) {
    QT_NULL_CHECK_RET(f, 0);
    QT_RETURN(int, static_cast<QFont*>(f)->pointSize());
}

extern "C" void qt_font_set_bold(qt_font_t f, int bold) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(static_cast<QFont*>(f)->setBold(bold != 0));
}

extern "C" int qt_font_is_bold(qt_font_t f) {
    QT_NULL_CHECK_RET(f, 0);
    QT_RETURN(int, static_cast<QFont*>(f)->bold() ? 1 : 0);
}

extern "C" void qt_font_set_italic(qt_font_t f, int italic) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(static_cast<QFont*>(f)->setItalic(italic != 0));
}

extern "C" int qt_font_is_italic(qt_font_t f) {
    QT_NULL_CHECK_RET(f, 0);
    QT_RETURN(int, static_cast<QFont*>(f)->italic() ? 1 : 0);
}

extern "C" void qt_font_destroy(qt_font_t f) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(delete static_cast<QFont*>(f));
}

extern "C" void qt_widget_set_font(qt_widget_t w, qt_font_t f) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setFont(*static_cast<QFont*>(f)));
}

extern "C" qt_font_t qt_widget_font(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, nullptr);
    QT_RETURN(qt_font_t, new QFont(static_cast<QWidget*>(w)->font()));
}

// ============================================================
// Phase 8a: Color
// ============================================================

extern "C" qt_color_t qt_color_create_rgb(int r, int g, int b, int a) {
    QT_RETURN(qt_color_t, new QColor(r, g, b, a));
}

extern "C" qt_color_t qt_color_create_name(const char* name) {
    QT_RETURN(qt_color_t, new QColor(QString::fromUtf8(name)));
}

extern "C" int qt_color_red(qt_color_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QColor*>(c)->red());
}

extern "C" int qt_color_green(qt_color_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QColor*>(c)->green());
}

extern "C" int qt_color_blue(qt_color_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QColor*>(c)->blue());
}

extern "C" int qt_color_alpha(qt_color_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QColor*>(c)->alpha());
}

extern "C" const char* qt_color_name(qt_color_t c) {
    QT_NULL_CHECK_RET(c, "");
    QT_RETURN_STRING(static_cast<QColor*>(c)->name().toUtf8().toStdString());
}

extern "C" int qt_color_is_valid(qt_color_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QColor*>(c)->isValid() ? 1 : 0);
}

extern "C" void qt_color_destroy(qt_color_t c) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(delete static_cast<QColor*>(c));
}

// ============================================================
// Phase 8a: Font Dialog
// ============================================================

extern "C" qt_font_t qt_font_dialog_get_font(qt_widget_t parent) {
    QT_NULL_CHECK_RET(parent, nullptr);
    bool ok = false;
    QFont font = QFontDialog::getFont(&ok, QFont(),
                                       static_cast<QWidget*>(parent));
    if (ok) {
    QT_RETURN(qt_font_t, new QFont(font));
    }
    return nullptr;
}

// ============================================================
// Phase 8a: Color Dialog
// ============================================================

extern "C" qt_color_t qt_color_dialog_get_color(const char* initial,
                                                  qt_widget_t parent) {
    QColor init(QString::fromUtf8(initial));
    QColor color = QColorDialog::getColor(init,
                                           static_cast<QWidget*>(parent));
    QT_RETURN(qt_color_t, new QColor(color));
}

// ============================================================
// Phase 8b: Stacked Widget
// ============================================================

extern "C" qt_stacked_widget_t qt_stacked_widget_create(qt_widget_t parent) {
    QT_RETURN(qt_stacked_widget_t, new QStackedWidget(static_cast<QWidget*>(parent)));
}

extern "C" int qt_stacked_widget_add_widget(qt_stacked_widget_t sw,
                                             qt_widget_t w) {
    QT_NULL_CHECK_RET(sw, 0);
    QT_RETURN(int,
        static_cast<QStackedWidget*>(sw)->addWidget(
        static_cast<QWidget*>(w)));
}

extern "C" void qt_stacked_widget_set_current_index(qt_stacked_widget_t sw,
                                                     int idx) {
    QT_NULL_CHECK_VOID(sw);
    QT_VOID(static_cast<QStackedWidget*>(sw)->setCurrentIndex(idx));
}

extern "C" int qt_stacked_widget_current_index(qt_stacked_widget_t sw) {
    QT_NULL_CHECK_RET(sw, 0);
    QT_RETURN(int, static_cast<QStackedWidget*>(sw)->currentIndex());
}

extern "C" int qt_stacked_widget_count(qt_stacked_widget_t sw) {
    QT_NULL_CHECK_RET(sw, 0);
    QT_RETURN(int, static_cast<QStackedWidget*>(sw)->count());
}

extern "C" void qt_stacked_widget_on_current_changed(qt_stacked_widget_t sw,
                                                      qt_callback_int callback,
                                                      long callback_id) {
    QT_NULL_CHECK_VOID(sw);
    QT_VOID(
        QObject::connect(static_cast<QStackedWidget*>(sw),
        &QStackedWidget::currentChanged,
        [callback, callback_id](int index) {
        callback(callback_id, index);
        })
    );
}

// ============================================================
// Phase 8b: Dock Widget
// ============================================================

extern "C" qt_dock_widget_t qt_dock_widget_create(const char* title,
                                                    qt_widget_t parent) {
    QT_RETURN(qt_dock_widget_t,
        new QDockWidget(QString::fromUtf8(title),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_dock_widget_set_widget(qt_dock_widget_t dw,
                                           qt_widget_t w) {
    QT_NULL_CHECK_VOID(dw);
    QT_VOID(static_cast<QDockWidget*>(dw)->setWidget(static_cast<QWidget*>(w)));
}

extern "C" qt_widget_t qt_dock_widget_widget(qt_dock_widget_t dw) {
    QT_NULL_CHECK_RET(dw, nullptr);
    QT_RETURN(qt_widget_t, static_cast<QDockWidget*>(dw)->widget());
}

extern "C" void qt_dock_widget_set_title(qt_dock_widget_t dw,
                                          const char* title) {
    QT_NULL_CHECK_VOID(dw);
    QT_VOID(static_cast<QDockWidget*>(dw)->setWindowTitle(QString::fromUtf8(title)));
}

extern "C" const char* qt_dock_widget_title(qt_dock_widget_t dw) {
    QT_NULL_CHECK_RET(dw, "");
    QT_RETURN_STRING(static_cast<QDockWidget*>(dw)->windowTitle() .toUtf8().toStdString());
}

extern "C" void qt_dock_widget_set_floating(qt_dock_widget_t dw,
                                             int floating) {
    QT_NULL_CHECK_VOID(dw);
    QT_VOID(static_cast<QDockWidget*>(dw)->setFloating(floating != 0));
}

extern "C" int qt_dock_widget_is_floating(qt_dock_widget_t dw) {
    QT_NULL_CHECK_RET(dw, 0);
    QT_RETURN(int, static_cast<QDockWidget*>(dw)->isFloating() ? 1 : 0);
}

extern "C" void qt_main_window_add_dock_widget(qt_main_window_t mw, int area,
                                                qt_dock_widget_t dw) {
    QT_NULL_CHECK_VOID(mw);
    QT_VOID(
        static_cast<QMainWindow*>(mw)->addDockWidget(
        static_cast<Qt::DockWidgetArea>(area),
        static_cast<QDockWidget*>(dw))
    );
}

// ============================================================
// Phase 8c: System Tray Icon
// ============================================================

extern "C" qt_tray_icon_t qt_system_tray_icon_create(qt_icon_t icon,
                                                      qt_widget_t parent) {
    QT_RETURN(qt_tray_icon_t,
        new QSystemTrayIcon(*static_cast<QIcon*>(icon),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_system_tray_icon_set_tooltip(qt_tray_icon_t ti,
                                                 const char* text) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(static_cast<QSystemTrayIcon*>(ti)->setToolTip(QString::fromUtf8(text)));
}

extern "C" void qt_system_tray_icon_set_icon(qt_tray_icon_t ti,
                                              qt_icon_t icon) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(static_cast<QSystemTrayIcon*>(ti)->setIcon(*static_cast<QIcon*>(icon)));
}

extern "C" void qt_system_tray_icon_show(qt_tray_icon_t ti) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(static_cast<QSystemTrayIcon*>(ti)->show());
}

extern "C" void qt_system_tray_icon_hide(qt_tray_icon_t ti) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(static_cast<QSystemTrayIcon*>(ti)->hide());
}

extern "C" void qt_system_tray_icon_show_message(qt_tray_icon_t ti,
                                                  const char* title,
                                                  const char* msg,
                                                  int icon_type,
                                                  int msecs) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(
        static_cast<QSystemTrayIcon*>(ti)->showMessage(
        QString::fromUtf8(title),
        QString::fromUtf8(msg),
        static_cast<QSystemTrayIcon::MessageIcon>(icon_type),
        msecs)
    );
}

extern "C" void qt_system_tray_icon_set_context_menu(qt_tray_icon_t ti,
                                                      qt_menu_t menu) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(
        static_cast<QSystemTrayIcon*>(ti)->setContextMenu(
        static_cast<QMenu*>(menu))
    );
}

extern "C" void qt_system_tray_icon_on_activated(qt_tray_icon_t ti,
                                                  qt_callback_int callback,
                                                  long callback_id) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(
        QObject::connect(static_cast<QSystemTrayIcon*>(ti),
        &QSystemTrayIcon::activated,
        [callback, callback_id](QSystemTrayIcon::ActivationReason reason) {
        callback(callback_id, static_cast<int>(reason));
        })
    );
}

extern "C" int qt_system_tray_icon_is_available(void) {
    QT_RETURN(int, QSystemTrayIcon::isSystemTrayAvailable() ? 1 : 0);
}

extern "C" void qt_system_tray_icon_destroy(qt_tray_icon_t ti) {
    QT_NULL_CHECK_VOID(ti);
    QT_VOID(delete static_cast<QSystemTrayIcon*>(ti));
}

// ============================================================
// Phase 8d: QPainter
// ============================================================

extern "C" qt_pixmap_t qt_pixmap_create_blank(int w, int h) {
    QT_RETURN(qt_pixmap_t, new QPixmap(w, h));
}

extern "C" void qt_pixmap_fill(qt_pixmap_t pm, int r, int g, int b, int a) {
    QT_NULL_CHECK_VOID(pm);
    QT_VOID(static_cast<QPixmap*>(pm)->fill(QColor(r, g, b, a)));
}

extern "C" qt_painter_t qt_painter_create(qt_pixmap_t pixmap) {
    QT_RETURN(qt_painter_t, new QPainter(static_cast<QPixmap*>(pixmap)));
}

extern "C" void qt_painter_end(qt_painter_t p) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->end());
}

extern "C" void qt_painter_destroy(qt_painter_t p) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        QPainter* painter = static_cast<QPainter*>(p);
        if (painter->isActive()) {
        painter->end();
        }
        delete painter
    );
}

extern "C" void qt_painter_set_pen_color(qt_painter_t p,
                                          int r, int g, int b, int a) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        QPen pen = static_cast<QPainter*>(p)->pen();
        pen.setColor(QColor(r, g, b, a));
        static_cast<QPainter*>(p)->setPen(pen)
    );
}

extern "C" void qt_painter_set_pen_width(qt_painter_t p, int width) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        QPen pen = static_cast<QPainter*>(p)->pen();
        pen.setWidth(width);
        static_cast<QPainter*>(p)->setPen(pen)
    );
}

extern "C" void qt_painter_set_brush_color(qt_painter_t p,
                                            int r, int g, int b, int a) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->setBrush(QBrush(QColor(r, g, b, a))));
}

extern "C" void qt_painter_set_font(qt_painter_t p, qt_font_t font) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->setFont(*static_cast<QFont*>(font)));
}

extern "C" void qt_painter_set_antialiasing(qt_painter_t p, int enabled) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        static_cast<QPainter*>(p)->setRenderHint(QPainter::Antialiasing,
        enabled != 0)
    );
}

extern "C" void qt_painter_draw_line(qt_painter_t p,
                                      int x1, int y1, int x2, int y2) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->drawLine(x1, y1, x2, y2));
}

extern "C" void qt_painter_draw_rect(qt_painter_t p,
                                      int x, int y, int w, int h) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->drawRect(x, y, w, h));
}

extern "C" void qt_painter_fill_rect(qt_painter_t p,
                                      int x, int y, int w, int h,
                                      int r, int g, int b, int a) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->fillRect(x, y, w, h, QColor(r, g, b, a)));
}

extern "C" void qt_painter_draw_ellipse(qt_painter_t p,
                                         int x, int y, int w, int h) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->drawEllipse(x, y, w, h));
}

extern "C" void qt_painter_draw_text(qt_painter_t p,
                                      int x, int y, const char* text) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->drawText(x, y, QString::fromUtf8(text)));
}

extern "C" void qt_painter_draw_text_rect(qt_painter_t p,
                                           int x, int y, int w, int h,
                                           int flags, const char* text) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        static_cast<QPainter*>(p)->drawText(QRect(x, y, w, h), flags,
        QString::fromUtf8(text))
    );
}

extern "C" void qt_painter_draw_pixmap(qt_painter_t p,
                                        int x, int y, qt_pixmap_t pixmap) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        static_cast<QPainter*>(p)->drawPixmap(x, y,
        *static_cast<QPixmap*>(pixmap))
    );
}

extern "C" void qt_painter_draw_point(qt_painter_t p, int x, int y) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->drawPoint(x, y));
}

extern "C" void qt_painter_draw_arc(qt_painter_t p,
                                     int x, int y, int w, int h,
                                     int start_angle, int span_angle) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->drawArc(x, y, w, h, start_angle, span_angle));
}

extern "C" void qt_painter_save(qt_painter_t p) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->save());
}

extern "C" void qt_painter_restore(qt_painter_t p) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->restore());
}

extern "C" void qt_painter_translate(qt_painter_t p, int dx, int dy) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->translate(dx, dy));
}

extern "C" void qt_painter_rotate(qt_painter_t p, double angle) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->rotate(angle));
}

extern "C" void qt_painter_scale(qt_painter_t p, double sx, double sy) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(static_cast<QPainter*>(p)->scale(sx, sy));
}

// ============================================================
// Phase 8e: Drag and Drop
// ============================================================

// DropFilter — QObject subclass that intercepts DragEnter and Drop events
// Same pattern as KeyPressFilter from Phase 6
class DropFilter : public QObject {
public:
    qt_callback_string m_callback;
    long m_callback_id;
    std::string m_last_text;

    DropFilter(QWidget* target, qt_callback_string callback, long callback_id)
        : QObject(target), m_callback(callback), m_callback_id(callback_id) {
        target->setAcceptDrops(true);
        target->installEventFilter(this);
    }

    bool eventFilter(QObject* obj, QEvent* event) override {
        if (event->type() == QEvent::DragEnter) {
            auto* de = static_cast<QDragEnterEvent*>(event);
            if (de->mimeData()->hasText()) {
                de->acceptProposedAction();
                return true;
            }
        } else if (event->type() == QEvent::Drop) {
            auto* de = static_cast<QDropEvent*>(event);
            if (de->mimeData()->hasText()) {
                m_last_text = de->mimeData()->text().toUtf8().toStdString();
                de->acceptProposedAction();
                m_callback(m_callback_id, m_last_text.c_str());
                return true;
            }
        }
        return QObject::eventFilter(obj, event);
    }
};

extern "C" void qt_widget_set_accept_drops(qt_widget_t w, int accept) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setAcceptDrops(accept != 0));
}

extern "C" qt_drop_filter_t qt_drop_filter_install(qt_widget_t widget,
                                                    qt_callback_string callback,
                                                    long callback_id) {
    QT_NULL_CHECK_RET(widget, nullptr);
    QT_RETURN(qt_drop_filter_t, new DropFilter(static_cast<QWidget*>(widget), callback, callback_id));
}

extern "C" const char* qt_drop_filter_last_text(qt_drop_filter_t df) {
    QT_NULL_CHECK_RET(df, "");
    QT_RETURN(const char*, static_cast<DropFilter*>(df)->m_last_text.c_str());
}

extern "C" void qt_drop_filter_destroy(qt_drop_filter_t df) {
    QT_NULL_CHECK_VOID(df);
    QT_VOID(delete static_cast<DropFilter*>(df));
}

extern "C" void qt_drag_text(qt_widget_t source, const char* text) {
    QT_NULL_CHECK_VOID(source);
    QT_VOID(
        QDrag* drag = new QDrag(static_cast<QWidget*>(source));
        QMimeData* mimeData = new QMimeData;
        mimeData->setText(QString::fromUtf8(text));
        drag->setMimeData(mimeData);
        drag->exec(Qt::CopyAction)
    );
}

// ============================================================
// Phase 9: Double Spin Box
// ============================================================

extern "C" qt_double_spin_box_t qt_double_spin_box_create(qt_widget_t parent) {
    QT_RETURN(qt_double_spin_box_t, new QDoubleSpinBox(static_cast<QWidget*>(parent)));
}

extern "C" void qt_double_spin_box_set_value(qt_double_spin_box_t s, double value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QDoubleSpinBox*>(s)->setValue(value));
}

extern "C" double qt_double_spin_box_value(qt_double_spin_box_t s) {
    QT_RETURN(double, static_cast<QDoubleSpinBox*>(s)->value());
}

extern "C" void qt_double_spin_box_set_range(qt_double_spin_box_t s,
                                              double minimum, double maximum) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QDoubleSpinBox*>(s)->setRange(minimum, maximum));
}

extern "C" void qt_double_spin_box_set_single_step(qt_double_spin_box_t s,
                                                     double step) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QDoubleSpinBox*>(s)->setSingleStep(step));
}

extern "C" void qt_double_spin_box_set_decimals(qt_double_spin_box_t s,
                                                  int decimals) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QDoubleSpinBox*>(s)->setDecimals(decimals));
}

extern "C" int qt_double_spin_box_decimals(qt_double_spin_box_t s) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QDoubleSpinBox*>(s)->decimals());
}

extern "C" void qt_double_spin_box_set_prefix(qt_double_spin_box_t s,
                                               const char* prefix) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QDoubleSpinBox*>(s)->setPrefix(QString::fromUtf8(prefix)));
}

extern "C" void qt_double_spin_box_set_suffix(qt_double_spin_box_t s,
                                               const char* suffix) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QDoubleSpinBox*>(s)->setSuffix(QString::fromUtf8(suffix)));
}

extern "C" void qt_double_spin_box_on_value_changed(qt_double_spin_box_t s,
                                                      qt_callback_string callback,
                                                      long callback_id) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        QObject::connect(static_cast<QDoubleSpinBox*>(s),
        QOverload<double>::of(&QDoubleSpinBox::valueChanged),
        [callback, callback_id](double value) {
        char buf[64];
        snprintf(buf, sizeof(buf), "%.17g", value);
        callback(callback_id, buf);
        })
    );
}

// ============================================================
// Phase 9: Date Edit
// ============================================================

extern "C" qt_date_edit_t qt_date_edit_create(qt_widget_t parent) {
    QT_RETURN(qt_date_edit_t, new QDateEdit(static_cast<QWidget*>(parent)));
}

extern "C" void qt_date_edit_set_date(qt_date_edit_t d,
                                       int year, int month, int day) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDateEdit*>(d)->setDate(QDate(year, month, day)));
}

extern "C" int qt_date_edit_year(qt_date_edit_t d) {
    QT_NULL_CHECK_RET(d, 0);
    QT_RETURN(int, static_cast<QDateEdit*>(d)->date().year());
}

extern "C" int qt_date_edit_month(qt_date_edit_t d) {
    QT_NULL_CHECK_RET(d, 0);
    QT_RETURN(int, static_cast<QDateEdit*>(d)->date().month());
}

extern "C" int qt_date_edit_day(qt_date_edit_t d) {
    QT_NULL_CHECK_RET(d, 0);
    QT_RETURN(int, static_cast<QDateEdit*>(d)->date().day());
}

extern "C" const char* qt_date_edit_date_string(qt_date_edit_t d) {
    QT_NULL_CHECK_RET(d, "");
    QT_RETURN_STRING(static_cast<QDateEdit*>(d)->date() .toString(Qt::ISODate).toUtf8().toStdString());
}

extern "C" void qt_date_edit_set_minimum_date(qt_date_edit_t d,
                                               int year, int month, int day) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDateEdit*>(d)->setMinimumDate(QDate(year, month, day)));
}

extern "C" void qt_date_edit_set_maximum_date(qt_date_edit_t d,
                                               int year, int month, int day) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDateEdit*>(d)->setMaximumDate(QDate(year, month, day)));
}

extern "C" void qt_date_edit_set_calendar_popup(qt_date_edit_t d, int enabled) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDateEdit*>(d)->setCalendarPopup(enabled != 0));
}

extern "C" void qt_date_edit_set_display_format(qt_date_edit_t d,
                                                 const char* format) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDateEdit*>(d)->setDisplayFormat(QString::fromUtf8(format)));
}

extern "C" void qt_date_edit_on_date_changed(qt_date_edit_t d,
                                              qt_callback_string callback,
                                              long callback_id) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(
        QObject::connect(static_cast<QDateEdit*>(d),
        &QDateEdit::dateChanged,
        [callback, callback_id](const QDate& date) {
        std::string iso = date.toString(Qt::ISODate)
        .toUtf8().toStdString();
        callback(callback_id, iso.c_str());
        })
    );
}

// ============================================================
// Phase 9: Time Edit
// ============================================================

extern "C" qt_time_edit_t qt_time_edit_create(qt_widget_t parent) {
    QT_RETURN(qt_time_edit_t, new QTimeEdit(static_cast<QWidget*>(parent)));
}

extern "C" void qt_time_edit_set_time(qt_time_edit_t t,
                                       int hour, int minute, int second) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTimeEdit*>(t)->setTime(QTime(hour, minute, second)));
}

extern "C" int qt_time_edit_hour(qt_time_edit_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTimeEdit*>(t)->time().hour());
}

extern "C" int qt_time_edit_minute(qt_time_edit_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTimeEdit*>(t)->time().minute());
}

extern "C" int qt_time_edit_second(qt_time_edit_t t) {
    QT_NULL_CHECK_RET(t, 0);
    QT_RETURN(int, static_cast<QTimeEdit*>(t)->time().second());
}

extern "C" const char* qt_time_edit_time_string(qt_time_edit_t t) {
    QT_NULL_CHECK_RET(t, "");
    QT_RETURN_STRING(static_cast<QTimeEdit*>(t)->time() .toString(Qt::ISODate).toUtf8().toStdString());
}

extern "C" void qt_time_edit_set_display_format(qt_time_edit_t t,
                                                 const char* format) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(static_cast<QTimeEdit*>(t)->setDisplayFormat(QString::fromUtf8(format)));
}

extern "C" void qt_time_edit_on_time_changed(qt_time_edit_t t,
                                              qt_callback_string callback,
                                              long callback_id) {
    QT_NULL_CHECK_VOID(t);
    QT_VOID(
        QObject::connect(static_cast<QTimeEdit*>(t),
        &QTimeEdit::timeChanged,
        [callback, callback_id](const QTime& time) {
        std::string iso = time.toString(Qt::ISODate)
        .toUtf8().toStdString();
        callback(callback_id, iso.c_str());
        })
    );
}

// ============================================================
// Phase 9: Frame
// ============================================================

extern "C" qt_frame_t qt_frame_create(qt_widget_t parent) {
    QT_RETURN(qt_frame_t, new QFrame(static_cast<QWidget*>(parent)));
}

extern "C" void qt_frame_set_frame_shape(qt_frame_t f, int shape) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(
        static_cast<QFrame*>(f)->setFrameShape(
        static_cast<QFrame::Shape>(shape))
    );
}

extern "C" int qt_frame_frame_shape(qt_frame_t f) {
    QT_NULL_CHECK_RET(f, 0);
    QT_RETURN(int, static_cast<int>(static_cast<QFrame*>(f)->frameShape()));
}

extern "C" void qt_frame_set_frame_shadow(qt_frame_t f, int shadow) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(
        static_cast<QFrame*>(f)->setFrameShadow(
        static_cast<QFrame::Shadow>(shadow))
    );
}

extern "C" int qt_frame_frame_shadow(qt_frame_t f) {
    QT_NULL_CHECK_RET(f, 0);
    QT_RETURN(int, static_cast<int>(static_cast<QFrame*>(f)->frameShadow()));
}

extern "C" void qt_frame_set_line_width(qt_frame_t f, int width) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(static_cast<QFrame*>(f)->setLineWidth(width));
}

extern "C" int qt_frame_line_width(qt_frame_t f) {
    QT_NULL_CHECK_RET(f, 0);
    QT_RETURN(int, static_cast<QFrame*>(f)->lineWidth());
}

extern "C" void qt_frame_set_mid_line_width(qt_frame_t f, int width) {
    QT_NULL_CHECK_VOID(f);
    QT_VOID(static_cast<QFrame*>(f)->setMidLineWidth(width));
}

// ============================================================
// Phase 9: Progress Dialog
// ============================================================

extern "C" qt_progress_dialog_t qt_progress_dialog_create(
    const char* label, const char* cancel_text,
    int minimum, int maximum, qt_widget_t parent) {
    // Capture string args by value into std::string before dispatching
    std::string _label(label ? label : "");
    std::string _cancel(cancel_text ? cancel_text : "");
    qt_progress_dialog_t _result = nullptr;
    auto _create = [&]() {
        auto* pd = new QProgressDialog(
            QString::fromUtf8(_label.c_str()),
            QString::fromUtf8(_cancel.c_str()),
            minimum, maximum,
            static_cast<QWidget*>(parent));
        // Don't auto-show — let the user control visibility
        pd->setMinimumDuration(0);
        pd->reset();
        _result = static_cast<qt_progress_dialog_t>(pd);
    };
    if (is_qt_main_thread()) { _create(); }
    else { QMetaObject::invokeMethod(QCoreApplication::instance(), _create, Qt::BlockingQueuedConnection); }
    return _result;
}

extern "C" void qt_progress_dialog_set_value(qt_progress_dialog_t pd, int value) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->setValue(value));
}

extern "C" int qt_progress_dialog_value(qt_progress_dialog_t pd) {
    QT_NULL_CHECK_RET(pd, 0);
    QT_RETURN(int, static_cast<QProgressDialog*>(pd)->value());
}

extern "C" void qt_progress_dialog_set_range(qt_progress_dialog_t pd,
                                              int minimum, int maximum) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->setRange(minimum, maximum));
}

extern "C" void qt_progress_dialog_set_label_text(qt_progress_dialog_t pd,
                                                    const char* text) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->setLabelText(QString::fromUtf8(text)));
}

extern "C" int qt_progress_dialog_was_canceled(qt_progress_dialog_t pd) {
    QT_NULL_CHECK_RET(pd, 0);
    QT_RETURN(int, static_cast<QProgressDialog*>(pd)->wasCanceled() ? 1 : 0);
}

extern "C" void qt_progress_dialog_set_minimum_duration(qt_progress_dialog_t pd,
                                                         int msecs) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->setMinimumDuration(msecs));
}

extern "C" void qt_progress_dialog_set_auto_close(qt_progress_dialog_t pd,
                                                    int enabled) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->setAutoClose(enabled != 0));
}

extern "C" void qt_progress_dialog_set_auto_reset(qt_progress_dialog_t pd,
                                                    int enabled) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->setAutoReset(enabled != 0));
}

extern "C" void qt_progress_dialog_reset(qt_progress_dialog_t pd) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(static_cast<QProgressDialog*>(pd)->reset());
}

extern "C" void qt_progress_dialog_on_canceled(qt_progress_dialog_t pd,
                                                qt_callback_void callback,
                                                long callback_id) {
    QT_NULL_CHECK_VOID(pd);
    QT_VOID(
        QObject::connect(static_cast<QProgressDialog*>(pd),
        &QProgressDialog::canceled,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

// ============================================================
// Phase 9: Input Dialog (static convenience)
// ============================================================

extern "C" const char* qt_input_dialog_get_text(
    qt_widget_t parent, const char* title,
    const char* label, const char* default_text) {
    s_last_input_ok = false;
    QT_RETURN_STRING(QInputDialog::getText( static_cast<QWidget*>(parent), QString::fromUtf8(title), QString::fromUtf8(label), QLineEdit::Normal, QString::fromUtf8(default_text), &s_last_input_ok).toUtf8().toStdString());
}

extern "C" int qt_input_dialog_get_int(
    qt_widget_t parent, const char* title,
    const char* label, int value,
    int min_val, int max_val, int step) {
    s_last_input_ok = false;
    QT_RETURN(int,
        QInputDialog::getInt(
        static_cast<QWidget*>(parent),
        QString::fromUtf8(title),
        QString::fromUtf8(label),
        value, min_val, max_val, step,
        &s_last_input_ok));
}

extern "C" double qt_input_dialog_get_double(
    qt_widget_t parent, const char* title,
    const char* label, double value,
    double min_val, double max_val, int decimals) {
    s_last_input_ok = false;
    QT_RETURN(double,
        QInputDialog::getDouble(
        static_cast<QWidget*>(parent),
        QString::fromUtf8(title),
        QString::fromUtf8(label),
        value, min_val, max_val, decimals,
        &s_last_input_ok));
}

extern "C" const char* qt_input_dialog_get_item(
    qt_widget_t parent, const char* title,
    const char* label, const char* items_newline,
    int current, int editable) {
    s_last_input_ok = false;
    QStringList items = QString::fromUtf8(items_newline)
                            .split('\n', Qt::SkipEmptyParts);
    QT_RETURN_STRING(QInputDialog::getItem( static_cast<QWidget*>(parent), QString::fromUtf8(title), QString::fromUtf8(label), items, current, editable != 0, &s_last_input_ok).toUtf8().toStdString());
}

extern "C" int qt_input_dialog_was_accepted(void) {
    QT_RETURN(int, s_last_input_ok ? 1 : 0);
}

// ============================================================
// Phase 10: Form Layout
// ============================================================

extern "C" qt_layout_t qt_form_layout_create(qt_widget_t parent) {
    QT_RETURN(qt_layout_t, new QFormLayout(static_cast<QWidget*>(parent)));
}

extern "C" void qt_form_layout_add_row(qt_layout_t layout, const char* label,
                                        qt_widget_t field) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(
        static_cast<QFormLayout*>(layout)->addRow(
        QString::fromUtf8(label), static_cast<QWidget*>(field))
    );
}

extern "C" void qt_form_layout_add_row_widget(qt_layout_t layout,
                                               qt_widget_t label_widget,
                                               qt_widget_t field) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(
        static_cast<QFormLayout*>(layout)->addRow(
        static_cast<QWidget*>(label_widget), static_cast<QWidget*>(field))
    );
}

extern "C" void qt_form_layout_add_spanning_widget(qt_layout_t layout,
                                                     qt_widget_t widget) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(static_cast<QFormLayout*>(layout)->addRow(static_cast<QWidget*>(widget)));
}

extern "C" int qt_form_layout_row_count(qt_layout_t layout) {
    QT_NULL_CHECK_RET(layout, 0);
    QT_RETURN(int, static_cast<QFormLayout*>(layout)->rowCount());
}

// ============================================================
// Phase 10: Shortcut
// ============================================================

extern "C" qt_shortcut_t qt_shortcut_create(const char* key_sequence,
                                             qt_widget_t parent) {
    QT_RETURN(qt_shortcut_t,
        new QShortcut(QKeySequence(QString::fromUtf8(key_sequence)),
        static_cast<QWidget*>(parent)));
}

extern "C" void qt_shortcut_set_key(qt_shortcut_t s,
                                     const char* key_sequence) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        static_cast<QShortcut*>(s)->setKey(
        QKeySequence(QString::fromUtf8(key_sequence)))
    );
}

extern "C" void qt_shortcut_set_enabled(qt_shortcut_t s, int enabled) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QShortcut*>(s)->setEnabled(enabled != 0));
}

extern "C" int qt_shortcut_is_enabled(qt_shortcut_t s) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QShortcut*>(s)->isEnabled() ? 1 : 0);
}

extern "C" void qt_shortcut_on_activated(qt_shortcut_t s,
                                          qt_callback_void callback,
                                          long callback_id) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        QObject::connect(static_cast<QShortcut*>(s), &QShortcut::activated,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_shortcut_destroy(qt_shortcut_t s) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(delete static_cast<QShortcut*>(s));
}

// ============================================================
// Phase 10: Text Browser
// ============================================================

extern "C" qt_text_browser_t qt_text_browser_create(qt_widget_t parent) {
    QT_RETURN(qt_text_browser_t, new QTextBrowser(static_cast<QWidget*>(parent)));
}

extern "C" void qt_text_browser_set_html(qt_text_browser_t tb,
                                          const char* html) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QTextBrowser*>(tb)->setHtml(QString::fromUtf8(html)));
}

extern "C" void qt_text_browser_set_plain_text(qt_text_browser_t tb,
                                                const char* text) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QTextBrowser*>(tb)->setPlainText(QString::fromUtf8(text)));
}

extern "C" const char* qt_text_browser_plain_text(qt_text_browser_t tb) {
    QT_NULL_CHECK_RET(tb, "");
    QT_RETURN_STRING(static_cast<QTextBrowser*>(tb)->toPlainText() .toUtf8().toStdString());
}

extern "C" void qt_text_browser_set_open_external_links(qt_text_browser_t tb,
                                                          int enabled) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QTextBrowser*>(tb)->setOpenExternalLinks(enabled != 0));
}

extern "C" void qt_text_browser_set_source(qt_text_browser_t tb,
                                            const char* url) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(
        static_cast<QTextBrowser*>(tb)->setSource(
        QUrl(QString::fromUtf8(url)))
    );
}

extern "C" const char* qt_text_browser_source(qt_text_browser_t tb) {
    QT_NULL_CHECK_RET(tb, "");
    QT_RETURN_STRING(static_cast<QTextBrowser*>(tb)->source() .toString().toUtf8().toStdString());
}

extern "C" void qt_text_browser_on_anchor_clicked(qt_text_browser_t tb,
                                                    qt_callback_string callback,
                                                    long callback_id) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(
        static_cast<QTextBrowser*>(tb)->setOpenLinks(false);
        QObject::connect(static_cast<QTextBrowser*>(tb),
        &QTextBrowser::anchorClicked,
        [callback, callback_id](const QUrl& url) {
        std::string s = url.toString().toUtf8().toStdString();
        callback(callback_id, s.c_str());
        })
    );
}

extern "C" void qt_text_browser_scroll_to_bottom(qt_text_browser_t tb) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(
        auto* te = static_cast<QTextBrowser*>(tb);
        auto* sb = te->verticalScrollBar();
        sb->setValue(sb->maximum())
    );
}

extern "C" void qt_text_browser_append(qt_text_browser_t tb, const char* text) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QTextBrowser*>(tb)->append(QString::fromUtf8(text)));
}

extern "C" const char* qt_text_browser_html(qt_text_browser_t tb) {
    QT_NULL_CHECK_RET(tb, "");
    QT_RETURN_STRING(static_cast<QTextBrowser*>(tb)->toHtml().toUtf8().toStdString());
}

// ============================================================
// Phase 10: Dialog Button Box
// ============================================================

extern "C" qt_button_box_t qt_button_box_create(int standard_buttons,
                                                  qt_widget_t parent) {
    QT_RETURN(qt_button_box_t,
        new QDialogButtonBox(
        static_cast<QDialogButtonBox::StandardButtons>(standard_buttons),
        static_cast<QWidget*>(parent)));
}

extern "C" qt_push_button_t qt_button_box_button(qt_button_box_t bb,
                                                   int standard_button) {
    QT_NULL_CHECK_RET(bb, nullptr);
    QT_RETURN(qt_push_button_t,
        static_cast<QDialogButtonBox*>(bb)->button(
        static_cast<QDialogButtonBox::StandardButton>(standard_button)));
}

extern "C" void qt_button_box_add_button(qt_button_box_t bb,
                                          qt_push_button_t button, int role) {
    QT_NULL_CHECK_VOID(bb);
    QT_VOID(
        static_cast<QDialogButtonBox*>(bb)->addButton(
        static_cast<QPushButton*>(button),
        static_cast<QDialogButtonBox::ButtonRole>(role))
    );
}

extern "C" void qt_button_box_on_accepted(qt_button_box_t bb,
                                           qt_callback_void callback,
                                           long callback_id) {
    QT_NULL_CHECK_VOID(bb);
    QT_VOID(
        QObject::connect(static_cast<QDialogButtonBox*>(bb),
        &QDialogButtonBox::accepted,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_button_box_on_rejected(qt_button_box_t bb,
                                           qt_callback_void callback,
                                           long callback_id) {
    QT_NULL_CHECK_VOID(bb);
    QT_VOID(
        QObject::connect(static_cast<QDialogButtonBox*>(bb),
        &QDialogButtonBox::rejected,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_button_box_on_clicked(qt_button_box_t bb,
                                          qt_callback_void callback,
                                          long callback_id) {
    QT_NULL_CHECK_VOID(bb);
    QT_VOID(
        QObject::connect(static_cast<QDialogButtonBox*>(bb),
        &QDialogButtonBox::clicked,
        [callback, callback_id](QAbstractButton*) {
        callback(callback_id);
        })
    );
}

// ============================================================
// Phase 10: Calendar Widget
// ============================================================

extern "C" qt_calendar_t qt_calendar_create(qt_widget_t parent) {
    QT_RETURN(qt_calendar_t, new QCalendarWidget(static_cast<QWidget*>(parent)));
}

extern "C" void qt_calendar_set_selected_date(qt_calendar_t c,
                                               int year, int month, int day) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCalendarWidget*>(c)->setSelectedDate(
        QDate(year, month, day))
    );
}

extern "C" int qt_calendar_selected_year(qt_calendar_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QCalendarWidget*>(c)->selectedDate().year());
}

extern "C" int qt_calendar_selected_month(qt_calendar_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QCalendarWidget*>(c)->selectedDate().month());
}

extern "C" int qt_calendar_selected_day(qt_calendar_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QCalendarWidget*>(c)->selectedDate().day());
}

extern "C" const char* qt_calendar_selected_date_string(qt_calendar_t c) {
    QT_NULL_CHECK_RET(c, "");
    QT_RETURN_STRING(static_cast<QCalendarWidget*>(c)->selectedDate() .toString(Qt::ISODate).toUtf8().toStdString());
}

extern "C" void qt_calendar_set_minimum_date(qt_calendar_t c,
                                              int year, int month, int day) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCalendarWidget*>(c)->setMinimumDate(
        QDate(year, month, day))
    );
}

extern "C" void qt_calendar_set_maximum_date(qt_calendar_t c,
                                              int year, int month, int day) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCalendarWidget*>(c)->setMaximumDate(
        QDate(year, month, day))
    );
}

extern "C" void qt_calendar_set_first_day_of_week(qt_calendar_t c, int day) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCalendarWidget*>(c)->setFirstDayOfWeek(
        static_cast<Qt::DayOfWeek>(day))
    );
}

extern "C" void qt_calendar_set_grid_visible(qt_calendar_t c, int visible) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QCalendarWidget*>(c)->setGridVisible(visible != 0));
}

extern "C" int qt_calendar_is_grid_visible(qt_calendar_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QCalendarWidget*>(c)->isGridVisible() ? 1 : 0);
}

extern "C" void qt_calendar_set_navigation_bar_visible(qt_calendar_t c,
                                                         int visible) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QCalendarWidget*>(c)->setNavigationBarVisible(visible != 0));
}

extern "C" void qt_calendar_on_selection_changed(qt_calendar_t c,
                                                   qt_callback_void callback,
                                                   long callback_id) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        QObject::connect(static_cast<QCalendarWidget*>(c),
        &QCalendarWidget::selectionChanged,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_calendar_on_clicked(qt_calendar_t c,
                                        qt_callback_string callback,
                                        long callback_id) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        QObject::connect(static_cast<QCalendarWidget*>(c),
        &QCalendarWidget::clicked,
        [callback, callback_id](const QDate& date) {
        std::string iso = date.toString(Qt::ISODate)
        .toUtf8().toStdString();
        callback(callback_id, iso.c_str());
        })
    );
}

// ============================================================
// Phase 11: QSettings
// ============================================================

extern "C" qt_settings_t qt_settings_create(const char* org, const char* app) {
    QT_RETURN(qt_settings_t, new QSettings(QString::fromUtf8(org), QString::fromUtf8(app)));
}

extern "C" qt_settings_t qt_settings_create_file(const char* path, int format) {
    QT_RETURN(qt_settings_t,
        new QSettings(QString::fromUtf8(path),
        static_cast<QSettings::Format>(format)));
}

extern "C" void qt_settings_set_string(qt_settings_t s, const char* key,
                                        const char* value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        static_cast<QSettings*>(s)->setValue(
        QString::fromUtf8(key), QString::fromUtf8(value))
    );
}

extern "C" const char* qt_settings_value_string(qt_settings_t s,
                                                  const char* key,
                                                  const char* default_value) {
    QT_NULL_CHECK_RET(s, "");
    QT_RETURN_STRING(static_cast<QSettings*>(s)->value( QString::fromUtf8(key), QString::fromUtf8(default_value)).toString().toUtf8().toStdString());
}

extern "C" void qt_settings_set_int(qt_settings_t s, const char* key,
                                     int value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->setValue(QString::fromUtf8(key), value));
}

extern "C" int qt_settings_value_int(qt_settings_t s, const char* key,
                                      int default_value) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int,
        static_cast<QSettings*>(s)->value(
        QString::fromUtf8(key), default_value).toInt());
}

extern "C" void qt_settings_set_double(qt_settings_t s, const char* key,
                                        double value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->setValue(QString::fromUtf8(key), value));
}

extern "C" double qt_settings_value_double(qt_settings_t s, const char* key,
                                            double default_value) {
    QT_RETURN(double,
        static_cast<QSettings*>(s)->value(
        QString::fromUtf8(key), default_value).toDouble());
}

extern "C" void qt_settings_set_bool(qt_settings_t s, const char* key,
                                      int value) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(
        static_cast<QSettings*>(s)->setValue(
        QString::fromUtf8(key), value != 0)
    );
}

extern "C" int qt_settings_value_bool(qt_settings_t s, const char* key,
                                       int default_value) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int,
        static_cast<QSettings*>(s)->value(
        QString::fromUtf8(key), default_value != 0).toBool() ? 1 : 0);
}

extern "C" int qt_settings_contains(qt_settings_t s, const char* key) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int,
        static_cast<QSettings*>(s)->contains(
        QString::fromUtf8(key)) ? 1 : 0);
}

extern "C" void qt_settings_remove(qt_settings_t s, const char* key) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->remove(QString::fromUtf8(key)));
}

extern "C" const char* qt_settings_all_keys(qt_settings_t s) {
    QT_NULL_CHECK_RET(s, "");
    QStringList keys = static_cast<QSettings*>(s)->allKeys();
    QT_RETURN_STRING(keys.join('\n').toUtf8().toStdString());
}

extern "C" const char* qt_settings_child_keys(qt_settings_t s) {
    QT_NULL_CHECK_RET(s, "");
    QStringList keys = static_cast<QSettings*>(s)->childKeys();
    QT_RETURN_STRING(keys.join('\n').toUtf8().toStdString());
}

extern "C" const char* qt_settings_child_groups(qt_settings_t s) {
    QT_NULL_CHECK_RET(s, "");
    QStringList groups = static_cast<QSettings*>(s)->childGroups();
    QT_RETURN_STRING(groups.join('\n').toUtf8().toStdString());
}

extern "C" void qt_settings_begin_group(qt_settings_t s, const char* prefix) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->beginGroup(QString::fromUtf8(prefix)));
}

extern "C" void qt_settings_end_group(qt_settings_t s) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->endGroup());
}

extern "C" const char* qt_settings_group(qt_settings_t s) {
    QT_NULL_CHECK_RET(s, "");
    QT_RETURN_STRING(static_cast<QSettings*>(s)->group().toUtf8().toStdString());
}

extern "C" void qt_settings_sync(qt_settings_t s) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->sync());
}

extern "C" void qt_settings_clear(qt_settings_t s) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(static_cast<QSettings*>(s)->clear());
}

extern "C" const char* qt_settings_file_name(qt_settings_t s) {
    QT_NULL_CHECK_RET(s, "");
    QT_RETURN_STRING(static_cast<QSettings*>(s)->fileName() .toUtf8().toStdString());
}

extern "C" int qt_settings_is_writable(qt_settings_t s) {
    QT_NULL_CHECK_RET(s, 0);
    QT_RETURN(int, static_cast<QSettings*>(s)->isWritable() ? 1 : 0);
}

extern "C" void qt_settings_destroy(qt_settings_t s) {
    QT_NULL_CHECK_VOID(s);
    QT_VOID(delete static_cast<QSettings*>(s));
}

// ============================================================
// Phase 11: QCompleter
// ============================================================

extern "C" qt_completer_t qt_completer_create(const char* items_newline) {
    QStringList items = QString::fromUtf8(items_newline)
                            .split('\n', Qt::SkipEmptyParts);
    auto* completer = new QCompleter(items);
    QT_RETURN(qt_completer_t, completer);
}

extern "C" void qt_completer_set_model_strings(qt_completer_t c,
                                                const char* items_newline) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        QStringList items = QString::fromUtf8(items_newline)
        .split('\n', Qt::SkipEmptyParts);
        auto* completer = static_cast<QCompleter*>(c);
        auto* model = qobject_cast<QStringListModel*>(completer->model());
        if (model) {
        model->setStringList(items);
        } else {
        completer->setModel(new QStringListModel(items, completer));
        }
    );
}

extern "C" void qt_completer_set_case_sensitivity(qt_completer_t c, int cs) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCompleter*>(c)->setCaseSensitivity(
        cs != 0 ? Qt::CaseSensitive : Qt::CaseInsensitive)
    );
}

extern "C" void qt_completer_set_completion_mode(qt_completer_t c, int mode) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCompleter*>(c)->setCompletionMode(
        static_cast<QCompleter::CompletionMode>(mode))
    );
}

extern "C" void qt_completer_set_filter_mode(qt_completer_t c, int mode) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        Qt::MatchFlags flags;
        switch (mode) {
        case 0: flags = Qt::MatchStartsWith; break;
        case 1: flags = Qt::MatchContains; break;
        case 2: flags = Qt::MatchEndsWith; break;
        default: flags = Qt::MatchStartsWith; break;
        }
        static_cast<QCompleter*>(c)->setFilterMode(flags)
    );
}

extern "C" void qt_completer_set_max_visible_items(qt_completer_t c,
                                                     int count) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(static_cast<QCompleter*>(c)->setMaxVisibleItems(count));
}

extern "C" int qt_completer_completion_count(qt_completer_t c) {
    QT_NULL_CHECK_RET(c, 0);
    QT_RETURN(int, static_cast<QCompleter*>(c)->completionCount());
}

extern "C" const char* qt_completer_current_completion(qt_completer_t c) {
    QT_NULL_CHECK_RET(c, "");
    QT_RETURN_STRING(static_cast<QCompleter*>(c)->currentCompletion() .toUtf8().toStdString());
}

extern "C" void qt_completer_set_completion_prefix(qt_completer_t c,
                                                    const char* prefix) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        static_cast<QCompleter*>(c)->setCompletionPrefix(
        QString::fromUtf8(prefix))
    );
}

extern "C" void qt_completer_on_activated(qt_completer_t c,
                                           qt_callback_string callback,
                                           long callback_id) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(
        QObject::connect(static_cast<QCompleter*>(c),
        QOverload<const QString&>::of(&QCompleter::activated),
        [callback, callback_id](const QString& text) {
        std::string s = text.toUtf8().toStdString();
        callback(callback_id, s.c_str());
        })
    );
}

extern "C" void qt_line_edit_set_completer(qt_line_edit_t e,
                                            qt_completer_t c) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        static_cast<QLineEdit*>(e)->setCompleter(
        static_cast<QCompleter*>(c))
    );
}

extern "C" void qt_completer_destroy(qt_completer_t c) {
    QT_NULL_CHECK_VOID(c);
    QT_VOID(delete static_cast<QCompleter*>(c));
}

// ============================================================
// Phase 11: QToolTip / QWhatsThis
// ============================================================

extern "C" void qt_tooltip_show_text(int x, int y, const char* text,
                                      qt_widget_t widget) {
    QT_VOID(
        QToolTip::showText(QPoint(x, y), QString::fromUtf8(text),
        static_cast<QWidget*>(widget))
    );
}

extern "C" void qt_tooltip_hide_text(void) {
    QT_VOID(QToolTip::hideText());
}

extern "C" int qt_tooltip_is_visible(void) {
    QT_RETURN(int, QToolTip::isVisible() ? 1 : 0);
}

extern "C" const char* qt_widget_tooltip(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, "");
    QT_RETURN_STRING(static_cast<QWidget*>(w)->toolTip().toUtf8().toStdString());
}

extern "C" void qt_widget_set_whats_this(qt_widget_t w, const char* text) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->setWhatsThis(QString::fromUtf8(text)));
}

extern "C" const char* qt_widget_whats_this(qt_widget_t w) {
    QT_NULL_CHECK_RET(w, "");
    QT_RETURN_STRING(static_cast<QWidget*>(w)->whatsThis() .toUtf8().toStdString());
}

/* ================================================================
   Phase 12: Model/View Framework
   ================================================================ */

/* --- QStandardItemModel --- */

extern "C" qt_standard_model_t qt_standard_model_create(int rows, int cols,
                                                          qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_standard_model_t, new QStandardItemModel(rows, cols, p));
}

extern "C" void qt_standard_model_destroy(qt_standard_model_t m) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(delete static_cast<QStandardItemModel*>(m));
}

extern "C" int qt_standard_model_row_count(qt_standard_model_t m) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStandardItemModel*>(m)->rowCount());
}

extern "C" int qt_standard_model_column_count(qt_standard_model_t m) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStandardItemModel*>(m)->columnCount());
}

extern "C" void qt_standard_model_set_row_count(qt_standard_model_t m, int rows) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(static_cast<QStandardItemModel*>(m)->setRowCount(rows));
}

extern "C" void qt_standard_model_set_column_count(qt_standard_model_t m, int cols) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(static_cast<QStandardItemModel*>(m)->setColumnCount(cols));
}

extern "C" void qt_standard_model_set_item(qt_standard_model_t m, int row,
                                             int col, qt_standard_item_t item) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(
        static_cast<QStandardItemModel*>(m)->setItem(
        row, col, static_cast<QStandardItem*>(item))
    );
}

extern "C" qt_standard_item_t qt_standard_model_item(qt_standard_model_t m,
                                                       int row, int col) {
    QT_NULL_CHECK_RET(m, nullptr);
    QT_RETURN(qt_standard_item_t, static_cast<QStandardItemModel*>(m)->item(row, col));
}

extern "C" int qt_standard_model_insert_row(qt_standard_model_t m, int row) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStandardItemModel*>(m)->insertRow(row) ? 1 : 0);
}

extern "C" int qt_standard_model_insert_column(qt_standard_model_t m, int col) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStandardItemModel*>(m)->insertColumn(col) ? 1 : 0);
}

extern "C" int qt_standard_model_remove_row(qt_standard_model_t m, int row) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStandardItemModel*>(m)->removeRow(row) ? 1 : 0);
}

extern "C" int qt_standard_model_remove_column(qt_standard_model_t m, int col) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStandardItemModel*>(m)->removeColumn(col) ? 1 : 0);
}

extern "C" void qt_standard_model_clear(qt_standard_model_t m) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(static_cast<QStandardItemModel*>(m)->clear());
}

extern "C" void qt_standard_model_set_horizontal_header(qt_standard_model_t m,
                                                          int col,
                                                          const char* text) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(
        static_cast<QStandardItemModel*>(m)->setHorizontalHeaderItem(
        col, new QStandardItem(QString::fromUtf8(text)))
    );
}

extern "C" void qt_standard_model_set_vertical_header(qt_standard_model_t m,
                                                        int row,
                                                        const char* text) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(
        static_cast<QStandardItemModel*>(m)->setVerticalHeaderItem(
        row, new QStandardItem(QString::fromUtf8(text)))
    );
}

/* --- QStandardItem --- */

extern "C" qt_standard_item_t qt_standard_item_create(const char* text) {
    QT_RETURN(qt_standard_item_t, new QStandardItem(QString::fromUtf8(text)));
}

extern "C" const char* qt_standard_item_text(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, "");
    QT_RETURN_STRING(static_cast<QStandardItem*>(item)->text() .toUtf8().toStdString());
}

extern "C" void qt_standard_item_set_text(qt_standard_item_t item,
                                            const char* text) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QStandardItem*>(item)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_standard_item_tooltip(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, "");
    QT_RETURN_STRING(static_cast<QStandardItem*>(item)->toolTip() .toUtf8().toStdString());
}

extern "C" void qt_standard_item_set_tooltip(qt_standard_item_t item,
                                               const char* text) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QStandardItem*>(item)->setToolTip(QString::fromUtf8(text)));
}

extern "C" void qt_standard_item_set_editable(qt_standard_item_t item, int val) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QStandardItem*>(item)->setEditable(val != 0));
}

extern "C" int qt_standard_item_is_editable(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QStandardItem*>(item)->isEditable() ? 1 : 0);
}

extern "C" void qt_standard_item_set_enabled(qt_standard_item_t item, int val) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QStandardItem*>(item)->setEnabled(val != 0));
}

extern "C" int qt_standard_item_is_enabled(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QStandardItem*>(item)->isEnabled() ? 1 : 0);
}

extern "C" void qt_standard_item_set_selectable(qt_standard_item_t item, int val) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QStandardItem*>(item)->setSelectable(val != 0));
}

extern "C" int qt_standard_item_is_selectable(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QStandardItem*>(item)->isSelectable() ? 1 : 0);
}

extern "C" void qt_standard_item_set_checkable(qt_standard_item_t item, int val) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QStandardItem*>(item)->setCheckable(val != 0));
}

extern "C" int qt_standard_item_is_checkable(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QStandardItem*>(item)->isCheckable() ? 1 : 0);
}

extern "C" void qt_standard_item_set_check_state(qt_standard_item_t item,
                                                    int state) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(
        static_cast<QStandardItem*>(item)->setCheckState(
        static_cast<Qt::CheckState>(state))
    );
}

extern "C" int qt_standard_item_check_state(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int,
        static_cast<int>(
        static_cast<QStandardItem*>(item)->checkState()));
}

extern "C" void qt_standard_item_set_icon(qt_standard_item_t item, void* icon) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(
        static_cast<QStandardItem*>(item)->setIcon(
        *static_cast<QIcon*>(icon))
    );
}

extern "C" void qt_standard_item_append_row(qt_standard_item_t parent,
                                              qt_standard_item_t child) {
    QT_NULL_CHECK_VOID(parent);
    QT_VOID(
        static_cast<QStandardItem*>(parent)->appendRow(
        static_cast<QStandardItem*>(child))
    );
}

extern "C" int qt_standard_item_row_count(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QStandardItem*>(item)->rowCount());
}

extern "C" int qt_standard_item_column_count(qt_standard_item_t item) {
    QT_NULL_CHECK_RET(item, 0);
    QT_RETURN(int, static_cast<QStandardItem*>(item)->columnCount());
}

extern "C" qt_standard_item_t qt_standard_item_child(qt_standard_item_t item,
                                                       int row, int col) {
    QT_NULL_CHECK_RET(item, nullptr);
    QT_RETURN(qt_standard_item_t, static_cast<QStandardItem*>(item)->child(row, col));
}

/* --- QStringListModel --- */

extern "C" qt_string_list_model_t qt_string_list_model_create(
        const char* items_newline) {
    auto* m = new QStringListModel();
    if (items_newline && items_newline[0]) {
        m->setStringList(QString::fromUtf8(items_newline)
                             .split('\n', Qt::SkipEmptyParts));
    }
    QT_RETURN(qt_string_list_model_t, m);
}

extern "C" void qt_string_list_model_destroy(qt_string_list_model_t m) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(delete static_cast<QStringListModel*>(m));
}

extern "C" void qt_string_list_model_set_strings(qt_string_list_model_t m,
                                                   const char* items_newline) {
    QT_NULL_CHECK_VOID(m);
    QT_VOID(
        QStringList list;
        if (items_newline && items_newline[0]) {
        list = QString::fromUtf8(items_newline)
        .split('\n', Qt::SkipEmptyParts);
        }
        static_cast<QStringListModel*>(m)->setStringList(list)
    );
}

extern "C" const char* qt_string_list_model_strings(qt_string_list_model_t m) {
    QT_NULL_CHECK_RET(m, "");
    QT_RETURN_STRING(static_cast<QStringListModel*>(m)->stringList() .join('\n').toUtf8().toStdString());
}

extern "C" int qt_string_list_model_row_count(qt_string_list_model_t m) {
    QT_NULL_CHECK_RET(m, 0);
    QT_RETURN(int, static_cast<QStringListModel*>(m)->rowCount());
}

/* --- Common view functions (QAbstractItemView) --- */

extern "C" void qt_view_set_model(qt_widget_t view, void* model) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        static_cast<QAbstractItemView*>(static_cast<QWidget*>(view))
        ->setModel(static_cast<QAbstractItemModel*>(model))
    );
}

extern "C" void qt_view_set_selection_mode(qt_widget_t view, int mode) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        static_cast<QAbstractItemView*>(static_cast<QWidget*>(view))
        ->setSelectionMode(
        static_cast<QAbstractItemView::SelectionMode>(mode))
    );
}

extern "C" void qt_view_set_selection_behavior(qt_widget_t view, int behavior) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        static_cast<QAbstractItemView*>(static_cast<QWidget*>(view))
        ->setSelectionBehavior(
        static_cast<QAbstractItemView::SelectionBehavior>(behavior))
    );
}

extern "C" void qt_view_set_alternating_row_colors(qt_widget_t view, int val) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        static_cast<QAbstractItemView*>(static_cast<QWidget*>(view))
        ->setAlternatingRowColors(val != 0)
    );
}

extern "C" void qt_view_set_sorting_enabled(qt_widget_t view, int val) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        // QAbstractItemView doesn't have setSortingEnabled directly;
        // QTableView and QTreeView do. Use dynamic_cast to detect.
        auto* tv = dynamic_cast<QTableView*>(static_cast<QWidget*>(view));
        if (tv) { tv->setSortingEnabled(val != 0); return; }
        auto* trv = dynamic_cast<QTreeView*>(static_cast<QWidget*>(view));
        if (trv) { trv->setSortingEnabled(val != 0); }
    );
}

extern "C" void qt_view_set_edit_triggers(qt_widget_t view, int triggers) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        static_cast<QAbstractItemView*>(static_cast<QWidget*>(view))
        ->setEditTriggers(
        static_cast<QAbstractItemView::EditTriggers>(triggers))
    );
}

/* --- QListView --- */

extern "C" qt_list_view_t qt_list_view_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_list_view_t, new QListView(p));
}

extern "C" void qt_list_view_set_flow(qt_list_view_t v, int flow) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(
        static_cast<QListView*>(v)->setFlow(
        static_cast<QListView::Flow>(flow))
    );
}

/* --- QTableView --- */

extern "C" qt_table_view_t qt_table_view_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_table_view_t, new QTableView(p));
}

extern "C" void qt_table_view_set_column_width(qt_table_view_t v,
                                                 int col, int w) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->setColumnWidth(col, w));
}

extern "C" void qt_table_view_set_row_height(qt_table_view_t v,
                                               int row, int h) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->setRowHeight(row, h));
}

extern "C" void qt_table_view_hide_column(qt_table_view_t v, int col) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->hideColumn(col));
}

extern "C" void qt_table_view_show_column(qt_table_view_t v, int col) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->showColumn(col));
}

extern "C" void qt_table_view_hide_row(qt_table_view_t v, int row) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->hideRow(row));
}

extern "C" void qt_table_view_show_row(qt_table_view_t v, int row) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->showRow(row));
}

extern "C" void qt_table_view_resize_columns_to_contents(qt_table_view_t v) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->resizeColumnsToContents());
}

extern "C" void qt_table_view_resize_rows_to_contents(qt_table_view_t v) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTableView*>(v)->resizeRowsToContents());
}

/* --- QTreeView --- */

extern "C" qt_tree_view_t qt_tree_view_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_tree_view_t, new QTreeView(p));
}

extern "C" void qt_tree_view_expand_all(qt_tree_view_t v) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTreeView*>(v)->expandAll());
}

extern "C" void qt_tree_view_collapse_all(qt_tree_view_t v) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTreeView*>(v)->collapseAll());
}

extern "C" void qt_tree_view_set_indentation(qt_tree_view_t v, int indent) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTreeView*>(v)->setIndentation(indent));
}

extern "C" int qt_tree_view_indentation(qt_tree_view_t v) {
    QT_NULL_CHECK_RET(v, 0);
    QT_RETURN(int, static_cast<QTreeView*>(v)->indentation());
}

extern "C" void qt_tree_view_set_root_is_decorated(qt_tree_view_t v, int val) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTreeView*>(v)->setRootIsDecorated(val != 0));
}

extern "C" void qt_tree_view_set_header_hidden(qt_tree_view_t v, int val) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTreeView*>(v)->setHeaderHidden(val != 0));
}

extern "C" void qt_tree_view_set_column_width(qt_tree_view_t v, int col, int w) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(static_cast<QTreeView*>(v)->setColumnWidth(col, w));
}

/* --- QHeaderView (via view) --- */

static QHeaderView* get_header(qt_widget_t view, int horizontal) {
    if (horizontal) {
        auto* tv = dynamic_cast<QTableView*>(static_cast<QWidget*>(view));
        if (tv) return tv->horizontalHeader();
        auto* trv = dynamic_cast<QTreeView*>(static_cast<QWidget*>(view));
        if (trv) return trv->header();
    } else {
        auto* tv = dynamic_cast<QTableView*>(static_cast<QWidget*>(view));
        if (tv) return tv->verticalHeader();
    }
    return nullptr;
}

extern "C" void qt_view_header_set_stretch_last_section(qt_widget_t view,
                                                          int horizontal,
                                                          int val) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* h = get_header(view, horizontal);
        if (h) h->setStretchLastSection(val != 0)
    );
}

extern "C" void qt_view_header_set_section_resize_mode(qt_widget_t view,
                                                         int horizontal,
                                                         int mode) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* h = get_header(view, horizontal);
        if (h) h->setSectionResizeMode(
        static_cast<QHeaderView::ResizeMode>(mode))
    );
}

extern "C" void qt_view_header_hide(qt_widget_t view, int horizontal) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* h = get_header(view, horizontal);
        if (h) h->hide()
    );
}

extern "C" void qt_view_header_show(qt_widget_t view, int horizontal) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* h = get_header(view, horizontal);
        if (h) h->show()
    );
}

extern "C" void qt_view_header_set_default_section_size(qt_widget_t view,
                                                          int horizontal,
                                                          int size) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* h = get_header(view, horizontal);
        if (h) h->setDefaultSectionSize(size)
    );
}

/* --- QSortFilterProxyModel --- */

extern "C" qt_sort_filter_proxy_t qt_sort_filter_proxy_create(void* parent) {
    auto* p = parent ? static_cast<QObject*>(parent) : nullptr;
    QT_RETURN(qt_sort_filter_proxy_t, new QSortFilterProxyModel(p));
}

extern "C" void qt_sort_filter_proxy_destroy(qt_sort_filter_proxy_t p) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(delete static_cast<QSortFilterProxyModel*>(p));
}

extern "C" void qt_sort_filter_proxy_set_source_model(
        qt_sort_filter_proxy_t p, void* model) {
    QT_VOID(
        static_cast<QSortFilterProxyModel*>(p)->setSourceModel(
        static_cast<QAbstractItemModel*>(model))
    );
}

extern "C" void qt_sort_filter_proxy_set_filter_regex(
        qt_sort_filter_proxy_t p, const char* pattern) {
    QT_VOID(
        static_cast<QSortFilterProxyModel*>(p)->setFilterRegularExpression(
        QString::fromUtf8(pattern))
    );
}

extern "C" void qt_sort_filter_proxy_set_filter_column(
        qt_sort_filter_proxy_t p, int col) {
    QT_VOID(static_cast<QSortFilterProxyModel*>(p)->setFilterKeyColumn(col));
}

extern "C" void qt_sort_filter_proxy_set_filter_case_sensitivity(
        qt_sort_filter_proxy_t p, int cs) {
    QT_VOID(
        static_cast<QSortFilterProxyModel*>(p)->setFilterCaseSensitivity(
        static_cast<Qt::CaseSensitivity>(cs))
    );
}

extern "C" void qt_sort_filter_proxy_set_filter_role(
        qt_sort_filter_proxy_t p, int role) {
    QT_VOID(static_cast<QSortFilterProxyModel*>(p)->setFilterRole(role));
}

extern "C" void qt_sort_filter_proxy_sort(qt_sort_filter_proxy_t p,
                                            int col, int order) {
    QT_NULL_CHECK_VOID(p);
    QT_VOID(
        static_cast<QSortFilterProxyModel*>(p)->sort(
        col, static_cast<Qt::SortOrder>(order))
    );
}

extern "C" void qt_sort_filter_proxy_set_sort_role(
        qt_sort_filter_proxy_t p, int role) {
    QT_VOID(static_cast<QSortFilterProxyModel*>(p)->setSortRole(role));
}

extern "C" void qt_sort_filter_proxy_set_dynamic_sort_filter(
        qt_sort_filter_proxy_t p, int val) {
    QT_VOID(static_cast<QSortFilterProxyModel*>(p)->setDynamicSortFilter(val != 0));
}

extern "C" void qt_sort_filter_proxy_invalidate_filter(
        qt_sort_filter_proxy_t p) {
    QT_VOID(static_cast<QSortFilterProxyModel*>(p)->invalidate());
}

extern "C" int qt_sort_filter_proxy_row_count(qt_sort_filter_proxy_t p) {
    QT_NULL_CHECK_RET(p, 0);
    QT_RETURN(int, static_cast<QSortFilterProxyModel*>(p)->rowCount());
}

/* --- View signals + selection --- */

extern "C" void qt_view_on_clicked(qt_widget_t view,
                                     qt_callback_void callback,
                                     long callback_id) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QAbstractItemView*>(static_cast<QWidget*>(view));
        QObject::connect(v, &QAbstractItemView::clicked,
        [callback, callback_id](const QModelIndex& idx) {
        s_last_view_row = idx.row();
        s_last_view_col = idx.column();
        callback(callback_id);
        })
    );
}

extern "C" void qt_view_on_double_clicked(qt_widget_t view,
                                            qt_callback_void callback,
                                            long callback_id) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QAbstractItemView*>(static_cast<QWidget*>(view));
        QObject::connect(v, &QAbstractItemView::doubleClicked,
        [callback, callback_id](const QModelIndex& idx) {
        s_last_view_row = idx.row();
        s_last_view_col = idx.column();
        callback(callback_id);
        })
    );
}

extern "C" void qt_view_on_activated(qt_widget_t view,
                                       qt_callback_void callback,
                                       long callback_id) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QAbstractItemView*>(static_cast<QWidget*>(view));
        QObject::connect(v, &QAbstractItemView::activated,
        [callback, callback_id](const QModelIndex& idx) {
        s_last_view_row = idx.row();
        s_last_view_col = idx.column();
        callback(callback_id);
        })
    );
}

extern "C" void qt_view_on_selection_changed(qt_widget_t view,
                                               qt_callback_void callback,
                                               long callback_id) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QAbstractItemView*>(static_cast<QWidget*>(view));
        auto* sel = v->selectionModel();
        if (!sel) return;
        QObject::connect(sel, &QItemSelectionModel::selectionChanged,
        [callback, callback_id](const QItemSelection&, const QItemSelection&) {
        callback(callback_id);
        })
    );
}

extern "C" int qt_view_last_clicked_row(void) {
    QT_RETURN(int, s_last_view_row);
}

extern "C" int qt_view_last_clicked_col(void) {
    QT_RETURN(int, s_last_view_col);
}

extern "C" const char* qt_view_selected_rows(qt_widget_t view) {
    QT_NULL_CHECK_RET(view, "");
    auto* v = static_cast<QAbstractItemView*>(static_cast<QWidget*>(view));
    auto* sel = v->selectionModel();
    if (!sel) { s_return_buf.clear(); return s_return_buf.c_str(); }
    auto rows = sel->selectedRows();
    std::string result;
    for (int i = 0; i < rows.size(); i++) {
        if (i > 0) result += '\n';
        result += std::to_string(rows[i].row());
    }
    QT_RETURN_STRING(result);
}

extern "C" int qt_view_current_row(qt_widget_t view) {
    QT_NULL_CHECK_RET(view, 0);
    auto* v = static_cast<QAbstractItemView*>(static_cast<QWidget*>(view));
    auto idx = v->currentIndex();
    QT_RETURN(int, idx.isValid() ? idx.row() : -1);
}

/* ========== Phase 13: Practical Polish ========== */

/* --- QValidator --- */

extern "C" qt_validator_t qt_int_validator_create(int minimum, int maximum,
                                                    qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_validator_t,
        static_cast<void*>(new QIntValidator(minimum, maximum,
        static_cast<QObject*>(p))));
}

extern "C" qt_validator_t qt_double_validator_create(double bottom, double top,
                                                       int decimals,
                                                       qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_validator_t,
        static_cast<void*>(new QDoubleValidator(bottom, top, decimals,
        static_cast<QObject*>(p))));
}

extern "C" qt_validator_t qt_regex_validator_create(const char* pattern,
                                                      qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QRegularExpression re(QString::fromUtf8(pattern));
    QT_RETURN(qt_validator_t,
        static_cast<void*>(new QRegularExpressionValidator(re,
        static_cast<QObject*>(p))));
}

extern "C" void qt_validator_destroy(qt_validator_t v) {
    QT_NULL_CHECK_VOID(v);
    QT_VOID(delete static_cast<QValidator*>(v));
}

extern "C" int qt_validator_validate(qt_validator_t v, const char* input) {
    QT_NULL_CHECK_RET(v, 0);
    auto* val = static_cast<QValidator*>(v);
    QString str = QString::fromUtf8(input);
    QT_RETURN(int,
        [&]() -> int {
            int pos = 0;
            QValidator::State state = val->validate(str, pos);
            switch (state) {
                case QValidator::Invalid:       return QT_VALIDATOR_INVALID;
                case QValidator::Intermediate:  return QT_VALIDATOR_INTERMEDIATE;
                case QValidator::Acceptable:    return QT_VALIDATOR_ACCEPTABLE;
                default:                        return QT_VALIDATOR_INVALID;
            }
        }()
    );
}

extern "C" void qt_line_edit_set_validator(qt_line_edit_t e,
                                            qt_validator_t v) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QLineEdit*>(e)->setValidator(static_cast<const QValidator*>(v)));
}

extern "C" int qt_line_edit_has_acceptable_input(qt_line_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    QT_RETURN(int, static_cast<QLineEdit*>(e)->hasAcceptableInput() ? 1 : 0);
}

/* --- QPlainTextEdit --- */

extern "C" qt_plain_text_edit_t qt_plain_text_edit_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_plain_text_edit_t, static_cast<void*>(new QPlainTextEdit(p)));
}

extern "C" void qt_plain_text_edit_set_text(qt_plain_text_edit_t e,
                                              const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        pte->setUpdatesEnabled(false);
        pte->setPlainText(QString::fromUtf8(text));
        pte->setUpdatesEnabled(true)
    );
}

extern "C" const char* qt_plain_text_edit_text(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, "");
    QT_RETURN_STRING(static_cast<QPlainTextEdit*>(e)->toPlainText() .toUtf8().constData());
}

extern "C" void qt_plain_text_edit_append(qt_plain_text_edit_t e,
                                            const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->appendPlainText(QString::fromUtf8(text)));
}

extern "C" void qt_plain_text_edit_clear(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->clear());
}

extern "C" void qt_plain_text_edit_set_read_only(qt_plain_text_edit_t e,
                                                   int read_only) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->setReadOnly(read_only != 0));
}

extern "C" int qt_plain_text_edit_is_read_only(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    QT_RETURN(int, static_cast<QPlainTextEdit*>(e)->isReadOnly() ? 1 : 0);
}

extern "C" void qt_plain_text_edit_set_placeholder(qt_plain_text_edit_t e,
                                                     const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        static_cast<QPlainTextEdit*>(e)->setPlaceholderText(
        QString::fromUtf8(text))
    );
}

extern "C" int qt_plain_text_edit_line_count(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    QT_RETURN(int, static_cast<QPlainTextEdit*>(e)->blockCount());
}

extern "C" void qt_plain_text_edit_set_max_block_count(qt_plain_text_edit_t e,
                                                         int count) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->setMaximumBlockCount(count));
}

extern "C" int qt_plain_text_edit_cursor_line(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QTextCursor tc = pte->textCursor();
    QT_RETURN(int, tc.blockNumber());
}

extern "C" int qt_plain_text_edit_cursor_column(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QTextCursor tc = pte->textCursor();
    QT_RETURN(int, tc.columnNumber());
}

extern "C" void qt_plain_text_edit_set_line_wrap(qt_plain_text_edit_t e,
                                                   int mode) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        pte->setLineWrapMode(mode == 0 ? QPlainTextEdit::NoWrap
        : QPlainTextEdit::WidgetWidth)
    );
}

extern "C" void qt_plain_text_edit_on_text_changed(qt_plain_text_edit_t e,
                                                     qt_callback_void callback,
                                                     long callback_id) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        QObject::connect(pte, &QPlainTextEdit::textChanged,
        [callback, callback_id]() { callback(callback_id); })
    );
}

/* --- QToolButton --- */

extern "C" qt_tool_button_t qt_tool_button_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_tool_button_t, static_cast<void*>(new QToolButton(p)));
}

extern "C" void qt_tool_button_set_text(qt_tool_button_t b,
                                          const char* text) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(static_cast<QToolButton*>(b)->setText(QString::fromUtf8(text)));
}

extern "C" const char* qt_tool_button_text(qt_tool_button_t b) {
    QT_NULL_CHECK_RET(b, "");
    QT_RETURN_STRING(static_cast<QToolButton*>(b)->text() .toUtf8().constData());
}

extern "C" void qt_tool_button_set_icon(qt_tool_button_t b,
                                          const char* path) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        static_cast<QToolButton*>(b)->setIcon(
        QIcon(QString::fromUtf8(path)))
    );
}

extern "C" void qt_tool_button_set_menu(qt_tool_button_t b,
                                          qt_widget_t menu) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        static_cast<QToolButton*>(b)->setMenu(
        static_cast<QMenu*>(static_cast<QWidget*>(menu)))
    );
}

extern "C" void qt_tool_button_set_popup_mode(qt_tool_button_t b, int mode) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        static_cast<QToolButton*>(b)->setPopupMode(
        static_cast<QToolButton::ToolButtonPopupMode>(mode))
    );
}

extern "C" void qt_tool_button_set_auto_raise(qt_tool_button_t b, int val) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(static_cast<QToolButton*>(b)->setAutoRaise(val != 0));
}

extern "C" void qt_tool_button_set_arrow_type(qt_tool_button_t b, int arrow) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        static_cast<QToolButton*>(b)->setArrowType(
        static_cast<Qt::ArrowType>(arrow))
    );
}

extern "C" void qt_tool_button_set_tool_button_style(qt_tool_button_t b,
                                                       int style) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        static_cast<QToolButton*>(b)->setToolButtonStyle(
        static_cast<Qt::ToolButtonStyle>(style))
    );
}

extern "C" void qt_tool_button_on_clicked(qt_tool_button_t b,
                                            qt_callback_void callback,
                                            long callback_id) {
    QT_NULL_CHECK_VOID(b);
    QT_VOID(
        auto* btn = static_cast<QToolButton*>(b);
        QObject::connect(btn, &QToolButton::clicked,
        [callback, callback_id]() { callback(callback_id); })
    );
}

/* --- Layout spacers --- */

extern "C" void qt_layout_add_spacing(qt_layout_t layout, int size) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(
        auto* box = dynamic_cast<QBoxLayout*>(static_cast<QLayout*>(layout));
        if (box) box->addSpacing(size)
    );
}

/* --- QSizePolicy --- */

extern "C" void qt_widget_set_size_policy(qt_widget_t w, int h_policy,
                                            int v_policy) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(
        auto* widget = static_cast<QWidget*>(w);
        widget->setSizePolicy(static_cast<QSizePolicy::Policy>(h_policy),
        static_cast<QSizePolicy::Policy>(v_policy))
    );
}

extern "C" void qt_layout_set_stretch_factor(qt_layout_t layout,
                                               qt_widget_t widget,
                                               int stretch) {
    QT_NULL_CHECK_VOID(layout);
    QT_VOID(
        auto* box = dynamic_cast<QBoxLayout*>(static_cast<QLayout*>(layout));
        if (box) box->setStretchFactor(static_cast<QWidget*>(widget), stretch)
    );
}

/* ========== Phase 14: Graphics Scene & Custom Painting ========== */

/* --- QGraphicsScene --- */

extern "C" qt_graphics_scene_t qt_graphics_scene_create(double x, double y,
                                                          double w, double h) {
    QT_RETURN(qt_graphics_scene_t, static_cast<void*>(new QGraphicsScene(x, y, w, h)));
}

extern "C" qt_graphics_item_t qt_graphics_scene_add_rect(
        qt_graphics_scene_t scene, double x, double y, double w, double h) {
    auto* s = static_cast<QGraphicsScene*>(scene);
    QT_RETURN(qt_graphics_item_t, static_cast<void*>(s->addRect(x, y, w, h)));
}

extern "C" qt_graphics_item_t qt_graphics_scene_add_ellipse(
        qt_graphics_scene_t scene, double x, double y, double w, double h) {
    auto* s = static_cast<QGraphicsScene*>(scene);
    QT_RETURN(qt_graphics_item_t, static_cast<void*>(s->addEllipse(x, y, w, h)));
}

extern "C" qt_graphics_item_t qt_graphics_scene_add_line(
        qt_graphics_scene_t scene, double x1, double y1,
        double x2, double y2) {
    auto* s = static_cast<QGraphicsScene*>(scene);
    QT_RETURN(qt_graphics_item_t, static_cast<void*>(s->addLine(x1, y1, x2, y2)));
}

extern "C" qt_graphics_item_t qt_graphics_scene_add_text(
        qt_graphics_scene_t scene, const char* text) {
    auto* s = static_cast<QGraphicsScene*>(scene);
    // QGraphicsTextItem inherits QGraphicsObject (QObject + QGraphicsItem).
    // Must cast to QGraphicsItem* before void* to adjust for multiple inheritance.
    QGraphicsItem* item = s->addText(QString::fromUtf8(text));
    QT_RETURN(qt_graphics_item_t, static_cast<void*>(item));
}

extern "C" qt_graphics_item_t qt_graphics_scene_add_pixmap(
        qt_graphics_scene_t scene, qt_pixmap_t pixmap) {
    auto* s = static_cast<QGraphicsScene*>(scene);
    auto* pm = static_cast<QPixmap*>(pixmap);
    QT_RETURN(qt_graphics_item_t, static_cast<void*>(s->addPixmap(*pm)));
}

extern "C" void qt_graphics_scene_remove_item(qt_graphics_scene_t scene,
                                                qt_graphics_item_t item) {
    QT_NULL_CHECK_VOID(scene);
    QT_VOID(
        auto* s = static_cast<QGraphicsScene*>(scene);
        auto* i = static_cast<QGraphicsItem*>(item);
        s->removeItem(i);
        delete i
    );
}

extern "C" void qt_graphics_scene_clear(qt_graphics_scene_t scene) {
    QT_NULL_CHECK_VOID(scene);
    QT_VOID(static_cast<QGraphicsScene*>(scene)->clear());
}

extern "C" int qt_graphics_scene_items_count(qt_graphics_scene_t scene) {
    QT_NULL_CHECK_RET(scene, 0);
    QT_RETURN(int, static_cast<QGraphicsScene*>(scene)->items().size());
}

extern "C" void qt_graphics_scene_set_background(qt_graphics_scene_t scene,
                                                    int r, int g, int b) {
    QT_NULL_CHECK_VOID(scene);
    QT_VOID(static_cast<QGraphicsScene*>(scene)->setBackgroundBrush(QColor(r, g, b)));
}

extern "C" void qt_graphics_scene_destroy(qt_graphics_scene_t scene) {
    QT_NULL_CHECK_VOID(scene);
    QT_VOID(delete static_cast<QGraphicsScene*>(scene));
}

/* --- QGraphicsView --- */

extern "C" qt_graphics_view_t qt_graphics_view_create(
        qt_graphics_scene_t scene, qt_widget_t parent) {
    auto* s = static_cast<QGraphicsScene*>(scene);
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_graphics_view_t, static_cast<void*>(new QGraphicsView(s, p)));
}

extern "C" void qt_graphics_view_set_render_hint(qt_graphics_view_t view,
                                                    int hint, int on) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QGraphicsView*>(static_cast<QWidget*>(view));
        v->setRenderHint(static_cast<QPainter::RenderHint>(hint), on != 0)
    );
}

extern "C" void qt_graphics_view_set_drag_mode(qt_graphics_view_t view,
                                                  int mode) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QGraphicsView*>(static_cast<QWidget*>(view));
        v->setDragMode(static_cast<QGraphicsView::DragMode>(mode))
    );
}

extern "C" void qt_graphics_view_fit_in_view(qt_graphics_view_t view) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QGraphicsView*>(static_cast<QWidget*>(view));
        v->fitInView(v->sceneRect(), Qt::KeepAspectRatio)
    );
}

extern "C" void qt_graphics_view_scale(qt_graphics_view_t view,
                                         double sx, double sy) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QGraphicsView*>(static_cast<QWidget*>(view));
        v->scale(sx, sy)
    );
}

extern "C" void qt_graphics_view_center_on(qt_graphics_view_t view,
                                             double x, double y) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* v = static_cast<QGraphicsView*>(static_cast<QWidget*>(view));
        v->centerOn(x, y)
    );
}

/* --- QGraphicsItem --- */

extern "C" void qt_graphics_item_set_pos(qt_graphics_item_t item,
                                           double x, double y) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QGraphicsItem*>(item)->setPos(x, y));
}

extern "C" double qt_graphics_item_x(qt_graphics_item_t item) {
    QT_RETURN(double, static_cast<QGraphicsItem*>(item)->x());
}

extern "C" double qt_graphics_item_y(qt_graphics_item_t item) {
    QT_RETURN(double, static_cast<QGraphicsItem*>(item)->y());
}

extern "C" void qt_graphics_item_set_pen(qt_graphics_item_t item,
                                           int r, int g, int b, int width) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(
        auto* gi = static_cast<QGraphicsItem*>(item);
        QPen pen(QColor(r, g, b));
        pen.setWidth(width);
        // Try each abstract shape type
        if (auto* rect = dynamic_cast<QAbstractGraphicsShapeItem*>(gi))
        rect->setPen(pen);
        else if (auto* line = dynamic_cast<QGraphicsLineItem*>(gi))
        line->setPen(pen)
    );
}

extern "C" void qt_graphics_item_set_brush(qt_graphics_item_t item,
                                             int r, int g, int b) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(
        auto* gi = static_cast<QGraphicsItem*>(item);
        if (auto* shape = dynamic_cast<QAbstractGraphicsShapeItem*>(gi))
        shape->setBrush(QColor(r, g, b))
    );
}

extern "C" void qt_graphics_item_set_flags(qt_graphics_item_t item,
                                             int flags) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(
        auto* gi = static_cast<QGraphicsItem*>(item);
        QGraphicsItem::GraphicsItemFlags f;
        if (flags & QT_ITEM_MOVABLE)    f |= QGraphicsItem::ItemIsMovable;
        if (flags & QT_ITEM_SELECTABLE) f |= QGraphicsItem::ItemIsSelectable;
        if (flags & QT_ITEM_FOCUSABLE)  f |= QGraphicsItem::ItemIsFocusable;
        gi->setFlags(f)
    );
}

extern "C" void qt_graphics_item_set_tooltip(qt_graphics_item_t item,
                                               const char* text) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QGraphicsItem*>(item)->setToolTip(QString::fromUtf8(text)));
}

extern "C" void qt_graphics_item_set_zvalue(qt_graphics_item_t item,
                                              double z) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QGraphicsItem*>(item)->setZValue(z));
}

extern "C" double qt_graphics_item_zvalue(qt_graphics_item_t item) {
    QT_RETURN(double, static_cast<QGraphicsItem*>(item)->zValue());
}

extern "C" void qt_graphics_item_set_rotation(qt_graphics_item_t item,
                                                double angle) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QGraphicsItem*>(item)->setRotation(angle));
}

extern "C" void qt_graphics_item_set_scale(qt_graphics_item_t item,
                                             double factor) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QGraphicsItem*>(item)->setScale(factor));
}

extern "C" void qt_graphics_item_set_visible(qt_graphics_item_t item,
                                               int visible) {
    QT_NULL_CHECK_VOID(item);
    QT_VOID(static_cast<QGraphicsItem*>(item)->setVisible(visible != 0));
}

/* --- PaintWidget (custom paintEvent) --- */

// PaintWidget: QWidget subclass that fires a callback during paintEvent.
// No Q_OBJECT macro needed — just overrides a virtual method.
class PaintWidget : public QWidget {
public:
    PaintWidget(QWidget* parent = nullptr)
        : QWidget(parent), m_callback(nullptr), m_callback_id(0),
          m_painter(nullptr), m_in_paint(false) {}

    void setCallback(qt_callback_void callback, long callback_id) {
        m_callback = callback;
        m_callback_id = callback_id;
    }

    // M4: Only return painter when inside paintEvent callback
    QPainter* currentPainter() const { return m_in_paint ? m_painter : nullptr; }

protected:
    void paintEvent(QPaintEvent*) override {
        if (m_callback) {
            QPainter painter(this);
            m_painter = &painter;
            m_in_paint = true;
            m_callback(m_callback_id);
            m_in_paint = false;
            m_painter = nullptr;
            // painter.end() is called automatically by QPainter destructor
        }
    }

private:
    qt_callback_void m_callback;
    long m_callback_id;
    QPainter* m_painter;
    bool m_in_paint;
};

extern "C" qt_paint_widget_t qt_paint_widget_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_paint_widget_t, static_cast<void*>(new PaintWidget(p)));
}

extern "C" void qt_paint_widget_on_paint(qt_paint_widget_t w,
                                           qt_callback_void callback,
                                           long callback_id) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(
        static_cast<PaintWidget*>(static_cast<QWidget*>(w))
        ->setCallback(callback, callback_id)
    );
}

extern "C" qt_painter_t qt_paint_widget_painter(qt_paint_widget_t w) {
    QT_NULL_CHECK_RET(w, nullptr);
    auto* pw = static_cast<PaintWidget*>(static_cast<QWidget*>(w));
    QT_RETURN(qt_painter_t, static_cast<void*>(pw->currentPainter()));
}

extern "C" void qt_paint_widget_update(qt_paint_widget_t w) {
    QT_NULL_CHECK_VOID(w);
    QT_VOID(static_cast<QWidget*>(w)->update());
}

extern "C" int qt_paint_widget_width(qt_paint_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->width());
}

extern "C" int qt_paint_widget_height(qt_paint_widget_t w) {
    QT_NULL_CHECK_RET(w, 0);
    QT_RETURN(int, static_cast<QWidget*>(w)->height());
}

// ============================================================
// Phase 15: QProcess
// ============================================================

// Process exit code tracking — Gambit's SIGCHLD handler reaps child processes
// before QProcess can observe their exit status.  We intercept SIGCHLD with our
// own handler that captures exit codes for tracked PIDs, then forwards to
// Gambit's handler.
// Per-process tracking: supports up to MAX_TRACKED concurrent QProcess instances.
// All state is non-thread-local since Qt must run on a single thread.

// Signal-safe array for the SIGCHLD handler (only sig_atomic_t and simple ops).
static const int MAX_TRACKED_PROCESSES = 64;  // M3: increased from 16
struct TrackedProcess {
    volatile sig_atomic_t pid;
    volatile sig_atomic_t exit_code;
};
static TrackedProcess s_tracked_processes[MAX_TRACKED_PROCESSES] = {};

// Non-signal state: per-process callback storage (keyed by QProcess pointer).
struct ProcessInfo {
    qt_callback_int finished_cb;
    long finished_cb_id;
    int last_exit_code;
    pid_t pid;
};
static std::unordered_map<void*, ProcessInfo> s_process_info;

// SIGCHLD handler: only reaps our specifically tracked PIDs (not all children).
// This captures exit codes before Gambit's handler can reap them with waitpid(-1).
// Qt still detects process exit via pipe closure, so waitForFinished works.
static struct sigaction s_gambit_sigaction = {};
static int s_sigchld_refcount = 0;

static void qt_sigchld_handler(int sig) {
    int saved_errno = errno;
    // Only waitpid for our tracked PIDs — never waitpid(-1) which reaps all children
    for (int i = 0; i < MAX_TRACKED_PROCESSES; i++) {
        if (s_tracked_processes[i].pid > 0 && s_tracked_processes[i].exit_code < 0) {
            int wstatus;
            pid_t result = waitpid(s_tracked_processes[i].pid, &wstatus, WNOHANG);
            if (result == s_tracked_processes[i].pid) {
                if (WIFEXITED(wstatus)) {
                    s_tracked_processes[i].exit_code = WEXITSTATUS(wstatus);
                } else if (WIFSIGNALED(wstatus)) {
                    s_tracked_processes[i].exit_code = 128 + WTERMSIG(wstatus);
                }
            }
        }
    }
    // Forward to Gambit's handler so it can handle its own process ports.
    // H2: Check SA_SIGINFO to call the correct union member.
    if (s_gambit_sigaction.sa_flags & SA_SIGINFO) {
        if (s_gambit_sigaction.sa_sigaction) {
            siginfo_t si;
            memset(&si, 0, sizeof(si));
            si.si_signo = sig;
            s_gambit_sigaction.sa_sigaction(sig, &si, nullptr);
        }
    } else if (s_gambit_sigaction.sa_handler &&
               s_gambit_sigaction.sa_handler != SIG_DFL &&
               s_gambit_sigaction.sa_handler != SIG_IGN) {
        s_gambit_sigaction.sa_handler(sig);
    }
    errno = saved_errno;
}

static void qt_install_sigchld_handler() {
    if (s_sigchld_refcount == 0) {
        struct sigaction sa;
        memset(&sa, 0, sizeof(sa));
        sa.sa_handler = qt_sigchld_handler;
        sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
        sigemptyset(&sa.sa_mask);
        sigaction(SIGCHLD, &sa, &s_gambit_sigaction);
    }
    s_sigchld_refcount++;
}

static void qt_restore_sigchld_handler() {
    if (s_sigchld_refcount > 0) {
        s_sigchld_refcount--;
        if (s_sigchld_refcount == 0) {
            sigaction(SIGCHLD, &s_gambit_sigaction, nullptr);
        }
    }
}

static int qt_track_pid(pid_t pid) {
    for (int i = 0; i < MAX_TRACKED_PROCESSES; i++) {
        if (s_tracked_processes[i].pid == 0) {
            s_tracked_processes[i].pid = pid;
            s_tracked_processes[i].exit_code = -1;
            return i;
        }
    }
    return -1; // no slot available
}

static int qt_get_tracked_exit_code(pid_t pid) {
    for (int i = 0; i < MAX_TRACKED_PROCESSES; i++) {
        if (s_tracked_processes[i].pid == pid) {
            return s_tracked_processes[i].exit_code;
        }
    }
    return -1;
}

static void qt_untrack_pid(pid_t pid) {
    for (int i = 0; i < MAX_TRACKED_PROCESSES; i++) {
        if (s_tracked_processes[i].pid == pid) {
            s_tracked_processes[i].pid = 0;
            s_tracked_processes[i].exit_code = -1;
            break;
        }
    }
}

extern "C" qt_process_t qt_process_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QObject*>(static_cast<QWidget*>(parent))
                     : nullptr;
    auto* proc = new QProcess(p);
    QT_RETURN(qt_process_t, static_cast<void*>(proc));
}

extern "C" int qt_process_start(qt_process_t proc, const char* program,
                                 const char* args_str) {
    QT_NULL_CHECK_RET(proc, 0);
    QStringList args;
    if (args_str && args_str[0]) {
        args = QString::fromUtf8(args_str).split(
            QChar('\n'), Qt::SkipEmptyParts);
    }

    // Install our SIGCHLD handler to capture exit codes for tracked PIDs
    qt_install_sigchld_handler();

    auto* p = static_cast<QProcess*>(proc);
    p->start(QString::fromUtf8(program), args);
    bool started = p->waitForStarted(5000);  // M2: capture return value

    pid_t pid = static_cast<pid_t>(p->processId());
    if (pid > 0) {
        qt_track_pid(pid);
    }
    // Update per-process info (may already have a callback from on_finished)
    auto it = s_process_info.find(proc);
    if (it != s_process_info.end()) {
        it->second.pid = pid;
        it->second.last_exit_code = 0;
    } else {
        s_process_info[proc] = {nullptr, 0, 0, pid};
    }
    QT_RETURN(int, started ? 1 : 0);
}

extern "C" void qt_process_write(qt_process_t proc, const char* data) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(
        if (!data) return;  // M1: strlen(nullptr) would crash
        static_cast<QProcess*>(proc)->write(data)
    );
}

extern "C" void qt_process_close_write(qt_process_t proc) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(static_cast<QProcess*>(proc)->closeWriteChannel());
}

extern "C" const char* qt_process_read_stdout(qt_process_t proc) {
    QT_NULL_CHECK_RET(proc, "");
    QT_RETURN_STRING(static_cast<QProcess*>(proc) ->readAllStandardOutput().toStdString());
}

extern "C" const char* qt_process_read_stderr(qt_process_t proc) {
    QT_NULL_CHECK_RET(proc, "");
    QT_RETURN_STRING(static_cast<QProcess*>(proc) ->readAllStandardError().toStdString());
}

extern "C" int qt_process_wait_for_finished(qt_process_t proc, int msecs) {
    QT_NULL_CHECK_RET(proc, 0);
    auto* p = static_cast<QProcess*>(proc);
    pid_t pid = static_cast<pid_t>(p->processId());

    // Let QProcess do its normal waiting (uses pipe closure detection)
    p->waitForFinished(msecs);

    // Determine exit code: prefer our SIGCHLD-captured code (which reaps
    // specifically tracked PIDs before Gambit's handler can), fall back to Qt
    int exit_code = 0;
    int captured = qt_get_tracked_exit_code(pid);
    if (captured >= 0) {
        exit_code = captured;
    } else if (p->state() == QProcess::NotRunning &&
               p->exitStatus() == QProcess::NormalExit) {
        exit_code = p->exitCode();
    }

    bool finished = (p->state() == QProcess::NotRunning) || (captured >= 0);

    // Store exit code and clean up tracking
    if (finished) {
        auto it = s_process_info.find(static_cast<void*>(p));
        if (it != s_process_info.end()) {
            it->second.last_exit_code = exit_code;

            // Manually invoke on-finished callback if registered
            if (it->second.finished_cb) {
                it->second.finished_cb(it->second.finished_cb_id, exit_code);
            }
        }
        qt_untrack_pid(pid);
        qt_restore_sigchld_handler();
    }

    QT_RETURN(int, finished ? 1 : 0);
}

extern "C" int qt_process_exit_code(qt_process_t proc) {
    QT_NULL_CHECK_RET(proc, 0);
    auto it = s_process_info.find(proc);
    if (it != s_process_info.end()) {
    QT_RETURN(int, it->second.last_exit_code);
    }
    // Fallback: check Qt's own exit code
    return static_cast<QProcess*>(proc)->exitCode();
}

extern "C" int qt_process_state(qt_process_t proc) {
    QT_NULL_CHECK_RET(proc, 0);
    QT_RETURN(int, static_cast<int>(static_cast<QProcess*>(proc)->state()));
}

extern "C" void qt_process_kill(qt_process_t proc) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(static_cast<QProcess*>(proc)->kill());
}

extern "C" void qt_process_terminate(qt_process_t proc) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(static_cast<QProcess*>(proc)->terminate());
}

extern "C" void qt_process_on_finished(qt_process_t proc,
                                        qt_callback_int callback,
                                        long callback_id) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(
        // Store callback for manual invocation after our waitpid.
        // We do NOT also connect via QObject::connect because
        // qt_process_wait_for_finished already invokes the callback
        // manually, and the Qt signal would cause a double-fire.
        auto it = s_process_info.find(proc);
        if (it != s_process_info.end()) {
        it->second.finished_cb = callback;
        it->second.finished_cb_id = callback_id;
        } else {
        // Process not yet started — pre-register callback
        s_process_info[proc] = {callback, callback_id, 0, 0};
        }
    );
}

extern "C" void qt_process_on_ready_read(qt_process_t proc,
                                          qt_callback_void callback,
                                          long callback_id) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(
        QObject::connect(static_cast<QProcess*>(proc),
        &QProcess::readyReadStandardOutput,
        [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_process_destroy(qt_process_t proc) {
    QT_NULL_CHECK_VOID(proc);
    QT_VOID(
        auto it = s_process_info.find(proc);
        if (it != s_process_info.end()) {
        if (it->second.pid > 0) {
        qt_untrack_pid(it->second.pid);
        qt_restore_sigchld_handler();
        }
        s_process_info.erase(it);
        }
        delete static_cast<QProcess*>(proc)
    );
}

// ============================================================
// Phase 15: QWizard / QWizardPage
// ============================================================

extern "C" qt_wizard_t qt_wizard_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_wizard_t, static_cast<void*>(new QWizard(p)));
}

extern "C" int qt_wizard_add_page(qt_wizard_t wiz, qt_wizard_page_t page) {
    QT_NULL_CHECK_RET(wiz, 0);
    QT_RETURN(int,
        static_cast<QWizard*>(wiz)->addPage(
        static_cast<QWizardPage*>(page)));
}

extern "C" void qt_wizard_set_start_id(qt_wizard_t wiz, int id) {
    QT_NULL_CHECK_VOID(wiz);
    QT_VOID(static_cast<QWizard*>(wiz)->setStartId(id));
}

extern "C" int qt_wizard_current_id(qt_wizard_t wiz) {
    QT_NULL_CHECK_RET(wiz, 0);
    QT_RETURN(int, static_cast<QWizard*>(wiz)->currentId());
}

extern "C" void qt_wizard_set_title(qt_wizard_t wiz, const char* title) {
    QT_NULL_CHECK_VOID(wiz);
    QT_VOID(
        static_cast<QWizard*>(wiz)->setWindowTitle(
        QString::fromUtf8(title))
    );
}

extern "C" int qt_wizard_exec(qt_wizard_t wiz) {
    QT_NULL_CHECK_RET(wiz, 0);
    QT_RETURN(int, static_cast<QWizard*>(wiz)->exec());
}

extern "C" qt_wizard_page_t qt_wizard_page_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_wizard_page_t, static_cast<void*>(new QWizardPage(p)));
}

extern "C" void qt_wizard_page_set_title(qt_wizard_page_t page,
                                          const char* title) {
    QT_NULL_CHECK_VOID(page);
    QT_VOID(
        static_cast<QWizardPage*>(page)->setTitle(
        QString::fromUtf8(title))
    );
}

extern "C" void qt_wizard_page_set_subtitle(qt_wizard_page_t page,
                                             const char* subtitle) {
    QT_NULL_CHECK_VOID(page);
    QT_VOID(
        static_cast<QWizardPage*>(page)->setSubTitle(
        QString::fromUtf8(subtitle))
    );
}

extern "C" void qt_wizard_page_set_layout(qt_wizard_page_t page,
                                           qt_layout_t layout) {
    QT_NULL_CHECK_VOID(page);
    QT_VOID(
        static_cast<QWizardPage*>(page)->setLayout(
        static_cast<QLayout*>(layout))
    );
}

extern "C" void qt_wizard_on_current_changed(qt_wizard_t wiz,
                                              qt_callback_int callback,
                                              long callback_id) {
    QT_NULL_CHECK_VOID(wiz);
    QT_VOID(
        QObject::connect(static_cast<QWizard*>(wiz),
        &QWizard::currentIdChanged,
        [callback, callback_id](int id) {
        callback(callback_id, id);
        })
    );
}

// ============================================================
// Phase 15: QMdiArea / QMdiSubWindow
// ============================================================

extern "C" qt_mdi_area_t qt_mdi_area_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_mdi_area_t, static_cast<void*>(new QMdiArea(p)));
}

extern "C" qt_mdi_sub_window_t qt_mdi_area_add_sub_window(qt_mdi_area_t area,
                                                            qt_widget_t widget) {
    QT_NULL_CHECK_RET(area, nullptr);
    QT_RETURN(qt_mdi_sub_window_t,
        static_cast<void*>(
        static_cast<QMdiArea*>(area)->addSubWindow(
        static_cast<QWidget*>(widget))));
}

extern "C" void qt_mdi_area_remove_sub_window(qt_mdi_area_t area,
                                               qt_mdi_sub_window_t sub) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(
        static_cast<QMdiArea*>(area)->removeSubWindow(
        static_cast<QMdiSubWindow*>(sub))
    );
}

extern "C" qt_mdi_sub_window_t qt_mdi_area_active_sub_window(qt_mdi_area_t area) {
    QT_NULL_CHECK_RET(area, nullptr);
    QT_RETURN(qt_mdi_sub_window_t,
        static_cast<void*>(
        static_cast<QMdiArea*>(area)->activeSubWindow()));
}

extern "C" int qt_mdi_area_sub_window_count(qt_mdi_area_t area) {
    QT_NULL_CHECK_RET(area, 0);
    QT_RETURN(int, static_cast<QMdiArea*>(area)->subWindowList().size());
}

extern "C" void qt_mdi_area_cascade(qt_mdi_area_t area) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(static_cast<QMdiArea*>(area)->cascadeSubWindows());
}

extern "C" void qt_mdi_area_tile(qt_mdi_area_t area) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(static_cast<QMdiArea*>(area)->tileSubWindows());
}

extern "C" void qt_mdi_area_set_view_mode(qt_mdi_area_t area, int mode) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(
        static_cast<QMdiArea*>(area)->setViewMode(
        static_cast<QMdiArea::ViewMode>(mode))
    );
}

extern "C" void qt_mdi_sub_window_set_title(qt_mdi_sub_window_t sub,
                                             const char* title) {
    QT_NULL_CHECK_VOID(sub);
    QT_VOID(
        static_cast<QMdiSubWindow*>(sub)->setWindowTitle(
        QString::fromUtf8(title))
    );
}

extern "C" void qt_mdi_area_on_sub_window_activated(qt_mdi_area_t area,
                                                     qt_callback_void callback,
                                                     long callback_id) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(
        QObject::connect(static_cast<QMdiArea*>(area),
        &QMdiArea::subWindowActivated,
        [callback, callback_id](QMdiSubWindow*) {
        callback(callback_id);
        })
    );
}

// ============================================================
// Phase 16: QDial
// ============================================================

extern "C" qt_dial_t qt_dial_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_dial_t, static_cast<void*>(new QDial(p)));
}

extern "C" void qt_dial_set_value(qt_dial_t d, int val) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDial*>(d)->setValue(val));
}

extern "C" int qt_dial_value(qt_dial_t d) {
    QT_NULL_CHECK_RET(d, 0);
    QT_RETURN(int, static_cast<QDial*>(d)->value());
}

extern "C" void qt_dial_set_range(qt_dial_t d, int min, int max) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDial*>(d)->setRange(min, max));
}

extern "C" void qt_dial_set_notches_visible(qt_dial_t d, int visible) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDial*>(d)->setNotchesVisible(visible != 0));
}

extern "C" void qt_dial_set_wrapping(qt_dial_t d, int wrap) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(static_cast<QDial*>(d)->setWrapping(wrap != 0));
}

extern "C" void qt_dial_on_value_changed(qt_dial_t d,
                                          qt_callback_int callback,
                                          long callback_id) {
    QT_NULL_CHECK_VOID(d);
    QT_VOID(
        QObject::connect(static_cast<QDial*>(d),
        &QDial::valueChanged,
        [callback, callback_id](int value) {
        callback(callback_id, value);
        })
    );
}

// ============================================================
// Phase 16: QLCDNumber
// ============================================================

extern "C" qt_lcd_t qt_lcd_create(int digits, qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_lcd_t, static_cast<void*>(new QLCDNumber(digits, p)));
}

extern "C" void qt_lcd_display_int(qt_lcd_t lcd, int value) {
    QT_NULL_CHECK_VOID(lcd);
    QT_VOID(static_cast<QLCDNumber*>(lcd)->display(value));
}

extern "C" void qt_lcd_display_double(qt_lcd_t lcd, double value) {
    QT_NULL_CHECK_VOID(lcd);
    QT_VOID(static_cast<QLCDNumber*>(lcd)->display(value));
}

extern "C" void qt_lcd_display_string(qt_lcd_t lcd, const char* text) {
    QT_NULL_CHECK_VOID(lcd);
    QT_VOID(static_cast<QLCDNumber*>(lcd)->display(QString::fromUtf8(text)));
}

extern "C" void qt_lcd_set_mode(qt_lcd_t lcd, int mode) {
    QT_NULL_CHECK_VOID(lcd);
    QT_VOID(
        static_cast<QLCDNumber*>(lcd)->setMode(
        static_cast<QLCDNumber::Mode>(mode))
    );
}

extern "C" void qt_lcd_set_segment_style(qt_lcd_t lcd, int style) {
    QT_NULL_CHECK_VOID(lcd);
    QT_VOID(
        static_cast<QLCDNumber*>(lcd)->setSegmentStyle(
        static_cast<QLCDNumber::SegmentStyle>(style))
    );
}

// ============================================================
// Phase 16: QToolBox
// ============================================================

extern "C" qt_tool_box_t qt_tool_box_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
    QT_RETURN(qt_tool_box_t, static_cast<void*>(new QToolBox(p)));
}

extern "C" int qt_tool_box_add_item(qt_tool_box_t tb, qt_widget_t widget,
                                     const char* text) {
    QT_NULL_CHECK_RET(tb, 0);
    QT_RETURN(int,
        static_cast<QToolBox*>(tb)->addItem(
        static_cast<QWidget*>(widget), QString::fromUtf8(text)));
}

extern "C" void qt_tool_box_set_current_index(qt_tool_box_t tb, int idx) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBox*>(tb)->setCurrentIndex(idx));
}

extern "C" int qt_tool_box_current_index(qt_tool_box_t tb) {
    QT_NULL_CHECK_RET(tb, 0);
    QT_RETURN(int, static_cast<QToolBox*>(tb)->currentIndex());
}

extern "C" int qt_tool_box_count(qt_tool_box_t tb) {
    QT_NULL_CHECK_RET(tb, 0);
    QT_RETURN(int, static_cast<QToolBox*>(tb)->count());
}

extern "C" void qt_tool_box_set_item_text(qt_tool_box_t tb, int idx,
                                           const char* text) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(static_cast<QToolBox*>(tb)->setItemText(idx, QString::fromUtf8(text)));
}

extern "C" void qt_tool_box_on_current_changed(qt_tool_box_t tb,
                                                qt_callback_int callback,
                                                long callback_id) {
    QT_NULL_CHECK_VOID(tb);
    QT_VOID(
        QObject::connect(static_cast<QToolBox*>(tb),
        &QToolBox::currentChanged,
        [callback, callback_id](int idx) {
        callback(callback_id, idx);
        })
    );
}

// ============================================================
// Phase 16: QUndoStack / QUndoCommand
// ============================================================

// Custom QUndoCommand subclass that calls Scheme callbacks for undo/redo.
// Note: QUndoStack::push() calls redo() immediately — this is by design.
class SchemeUndoCommand : public QUndoCommand {
public:
    SchemeUndoCommand(const QString& text,
                      qt_callback_void undo_cb, long undo_id,
                      qt_callback_void redo_cb, long redo_id,
                      qt_callback_void cleanup_cb, long cleanup_id)
        : QUndoCommand(text)
        , m_undo_cb(undo_cb), m_undo_id(undo_id)
        , m_redo_cb(redo_cb), m_redo_id(redo_id)
        , m_cleanup_cb(cleanup_cb), m_cleanup_id(cleanup_id) {}

    ~SchemeUndoCommand() override {
        if (m_cleanup_cb) m_cleanup_cb(m_cleanup_id);
    }

    void undo() override {
        if (m_undo_cb) m_undo_cb(m_undo_id);
    }

    void redo() override {
        if (m_redo_cb) m_redo_cb(m_redo_id);
    }

private:
    qt_callback_void m_undo_cb;
    long m_undo_id;
    qt_callback_void m_redo_cb;
    long m_redo_id;
    qt_callback_void m_cleanup_cb;
    long m_cleanup_id;
};

extern "C" qt_undo_stack_t qt_undo_stack_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QObject*>(static_cast<QWidget*>(parent))
                     : nullptr;
    QT_RETURN(qt_undo_stack_t, static_cast<void*>(new QUndoStack(p)));
}

extern "C" void qt_undo_stack_push(qt_undo_stack_t stack, const char* text,
                                    qt_callback_void undo_cb, long undo_id,
                                    qt_callback_void redo_cb, long redo_id,
                                    qt_callback_void cleanup_cb, long cleanup_id) {
    QT_NULL_CHECK_VOID(stack);
    QT_VOID(
        auto* s = static_cast<QUndoStack*>(stack);
        auto* cmd = new SchemeUndoCommand(QString::fromUtf8(text),
        undo_cb, undo_id, redo_cb, redo_id,
        cleanup_cb, cleanup_id);
        s->push(cmd);  // QUndoStack takes ownership
    );
}

extern "C" void qt_undo_stack_undo(qt_undo_stack_t stack) {
    QT_NULL_CHECK_VOID(stack);
    QT_VOID(static_cast<QUndoStack*>(stack)->undo());
}

extern "C" void qt_undo_stack_redo(qt_undo_stack_t stack) {
    QT_NULL_CHECK_VOID(stack);
    QT_VOID(static_cast<QUndoStack*>(stack)->redo());
}

extern "C" int qt_undo_stack_can_undo(qt_undo_stack_t stack) {
    QT_NULL_CHECK_RET(stack, 0);
    QT_RETURN(int, static_cast<QUndoStack*>(stack)->canUndo() ? 1 : 0);
}

extern "C" int qt_undo_stack_can_redo(qt_undo_stack_t stack) {
    QT_NULL_CHECK_RET(stack, 0);
    QT_RETURN(int, static_cast<QUndoStack*>(stack)->canRedo() ? 1 : 0);
}

extern "C" const char* qt_undo_stack_undo_text(qt_undo_stack_t stack) {
    QT_NULL_CHECK_RET(stack, "");
    QT_RETURN_STRING(static_cast<QUndoStack*>(stack) ->undoText().toUtf8().toStdString());
}

extern "C" const char* qt_undo_stack_redo_text(qt_undo_stack_t stack) {
    QT_NULL_CHECK_RET(stack, "");
    QT_RETURN_STRING(static_cast<QUndoStack*>(stack) ->redoText().toUtf8().toStdString());
}

extern "C" void qt_undo_stack_clear(qt_undo_stack_t stack) {
    QT_NULL_CHECK_VOID(stack);
    QT_VOID(static_cast<QUndoStack*>(stack)->clear());
}

extern "C" qt_action_t qt_undo_stack_create_undo_action(qt_undo_stack_t stack,
                                                          qt_widget_t parent) {
    auto* p = parent ? static_cast<QObject*>(static_cast<QWidget*>(parent))
                     : nullptr;
    QT_RETURN(qt_action_t,
        static_cast<void*>(
        static_cast<QUndoStack*>(stack)->createUndoAction(p)));
}

extern "C" qt_action_t qt_undo_stack_create_redo_action(qt_undo_stack_t stack,
                                                          qt_widget_t parent) {
    auto* p = parent ? static_cast<QObject*>(static_cast<QWidget*>(parent))
                     : nullptr;
    QT_RETURN(qt_action_t,
        static_cast<void*>(
        static_cast<QUndoStack*>(stack)->createRedoAction(p)));
}

extern "C" void qt_undo_stack_destroy(qt_undo_stack_t stack) {
    QT_NULL_CHECK_VOID(stack);
    QT_VOID(delete static_cast<QUndoStack*>(stack));
}

// ============================================================
// Phase 16: QFileSystemModel
// ============================================================

extern "C" qt_file_system_model_t qt_file_system_model_create(qt_widget_t parent) {
    auto* p = parent ? static_cast<QObject*>(static_cast<QWidget*>(parent))
                     : nullptr;
    QT_RETURN(qt_file_system_model_t, static_cast<void*>(new QFileSystemModel(p)));
}

extern "C" void qt_file_system_model_set_root_path(qt_file_system_model_t model,
                                                     const char* path) {
    QT_NULL_CHECK_VOID(model);
    QT_VOID(
        static_cast<QFileSystemModel*>(model)->setRootPath(
        QString::fromUtf8(path))
    );
}

extern "C" void qt_file_system_model_set_filter(qt_file_system_model_t model,
                                                  int filters) {
    QT_NULL_CHECK_VOID(model);
    QT_VOID(
        static_cast<QFileSystemModel*>(model)->setFilter(
        static_cast<QDir::Filters>(filters))
    );
}

extern "C" void qt_file_system_model_set_name_filters(qt_file_system_model_t model,
                                                        const char* patterns) {
    QT_NULL_CHECK_VOID(model);
    QT_VOID(
        QStringList filters;
        if (patterns && patterns[0]) {
        filters = QString::fromUtf8(patterns).split(
        QChar('\n'), Qt::SkipEmptyParts);
        }
        static_cast<QFileSystemModel*>(model)->setNameFilters(filters)
    );
}

extern "C" const char* qt_file_system_model_file_path(qt_file_system_model_t model,
                                                        int row, int column) {
    QT_NULL_CHECK_RET(model, "");
    auto* m = static_cast<QFileSystemModel*>(model);
    QModelIndex idx = m->index(row, column, m->index(m->rootPath()));
    QT_RETURN_STRING(m->filePath(idx).toUtf8().toStdString());
}

extern "C" void qt_tree_view_set_file_system_root(qt_widget_t view,
                                                    qt_file_system_model_t model,
                                                    const char* path) {
    QT_NULL_CHECK_VOID(view);
    QT_VOID(
        auto* tv = static_cast<QTreeView*>(view);
        auto* m = static_cast<QFileSystemModel*>(model);
        tv->setModel(m);
        tv->setRootIndex(m->index(QString::fromUtf8(path)))
    );
}

extern "C" void qt_file_system_model_destroy(qt_file_system_model_t model) {
    QT_NULL_CHECK_VOID(model);
    QT_VOID(delete static_cast<QFileSystemModel*>(model));
}

// ============================================================
// Phase 17: QPlainTextEdit Editor Extensions
// ============================================================

extern "C" int qt_plain_text_edit_cursor_position(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN(int, pte->textCursor().position());
}

extern "C" void qt_plain_text_edit_set_cursor_position(qt_plain_text_edit_t e,
                                                         int pos) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        QTextCursor tc = pte->textCursor();
        tc.setPosition(pos);
        pte->setTextCursor(tc)
    );
}

extern "C" void qt_plain_text_edit_move_cursor(qt_plain_text_edit_t e,
                                                 int operation, int mode) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        pte->moveCursor(static_cast<QTextCursor::MoveOperation>(operation),
        static_cast<QTextCursor::MoveMode>(mode))
    );
}

extern "C" void qt_plain_text_edit_select_all(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->selectAll());
}

extern "C" const char* qt_plain_text_edit_selected_text(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, "");
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN_STRING(pte->textCursor().selectedText().toUtf8().constData());
}

extern "C" int qt_plain_text_edit_selection_start(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN(int, pte->textCursor().selectionStart());
}

extern "C" int qt_plain_text_edit_selection_end(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN(int, pte->textCursor().selectionEnd());
}

extern "C" void qt_plain_text_edit_set_selection(qt_plain_text_edit_t e,
                                                   int start, int end) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        QTextCursor tc = pte->textCursor();
        tc.setPosition(start);
        tc.setPosition(end, QTextCursor::KeepAnchor);
        pte->setTextCursor(tc)
    );
}

extern "C" int qt_plain_text_edit_has_selection(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN(int, pte->textCursor().hasSelection() ? 1 : 0);
}

extern "C" void qt_plain_text_edit_insert_text(qt_plain_text_edit_t e,
                                                 const char* text) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        QTextCursor tc = pte->textCursor();
        tc.insertText(QString::fromUtf8(text));
        pte->setTextCursor(tc)
    );
}

extern "C" void qt_plain_text_edit_remove_selected_text(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        auto* pte = static_cast<QPlainTextEdit*>(e);
        QTextCursor tc = pte->textCursor();
        tc.removeSelectedText();
        pte->setTextCursor(tc)
    );
}

extern "C" void qt_plain_text_edit_undo(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->undo());
}

extern "C" void qt_plain_text_edit_redo(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->redo());
}

extern "C" int qt_plain_text_edit_can_undo(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN(int, pte->document()->isUndoAvailable() ? 1 : 0);
}

extern "C" void qt_plain_text_edit_cut(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->cut());
}

extern "C" void qt_plain_text_edit_copy(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->copy());
}

extern "C" void qt_plain_text_edit_paste(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->paste());
}

extern "C" int qt_plain_text_edit_text_length(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QT_RETURN(int, pte->document()->characterCount() - 1);
}

extern "C" const char* qt_plain_text_edit_text_range(qt_plain_text_edit_t e,
                                                       int start, int end) {
    QT_NULL_CHECK_RET(e, "");
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QTextCursor tc(pte->document());
    tc.setPosition(start);
    tc.setPosition(end, QTextCursor::KeepAnchor);
    QT_RETURN_STRING(tc.selectedText().toUtf8().constData());
}

extern "C" int qt_plain_text_edit_line_from_position(qt_plain_text_edit_t e,
                                                       int pos) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QTextCursor tc(pte->document());
    tc.setPosition(pos);
    QT_RETURN(int, tc.blockNumber());
}

extern "C" int qt_plain_text_edit_line_end_position(qt_plain_text_edit_t e,
                                                      int line) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QTextBlock block = pte->document()->findBlockByNumber(line);
    if (!block.isValid()) return -1;
    QT_RETURN(int, block.position() + block.length() - 1);
}

extern "C" int qt_plain_text_edit_find_text(qt_plain_text_edit_t e,
                                              const char* text, int flags) {
    QT_NULL_CHECK_RET(e, 0);
    auto* pte = static_cast<QPlainTextEdit*>(e);
    QTextDocument::FindFlags qflags;
    if (flags & 1) qflags |= QTextDocument::FindBackward;
    if (flags & 2) qflags |= QTextDocument::FindCaseSensitively;
    if (flags & 4) qflags |= QTextDocument::FindWholeWords;
    bool found = pte->find(QString::fromUtf8(text), qflags);
    QT_RETURN(int, found ? pte->textCursor().selectionStart() : -1);
}

extern "C" void qt_plain_text_edit_ensure_cursor_visible(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->ensureCursorVisible());
}

extern "C" void qt_plain_text_edit_center_cursor(qt_plain_text_edit_t e) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(static_cast<QPlainTextEdit*>(e)->centerCursor());
}

extern "C" void* qt_text_document_create(void) {
    QT_RETURN(void*, static_cast<void*>(new QTextDocument()));
}

extern "C" void* qt_plain_text_document_create(void) {
    void* _result = nullptr;
    auto _create = [&]() {
        auto* doc = new QTextDocument();
        auto* layout = new QPlainTextDocumentLayout(doc);
        doc->setDocumentLayout(layout);
        _result = static_cast<void*>(doc);
    };
    if (is_qt_main_thread()) { _create(); }
    else { QMetaObject::invokeMethod(QCoreApplication::instance(), _create, Qt::BlockingQueuedConnection); }
    return _result;
}

extern "C" void qt_text_document_destroy(void* doc) {
    QT_NULL_CHECK_VOID(doc);
    QT_VOID(delete static_cast<QTextDocument*>(doc));
}

extern "C" void* qt_plain_text_edit_document(qt_plain_text_edit_t e) {
    QT_RETURN(void*, static_cast<void*>(static_cast<QPlainTextEdit*>(e)->document()));
}

extern "C" void qt_plain_text_edit_set_document(qt_plain_text_edit_t e,
                                                  void* doc) {
    QT_NULL_CHECK_VOID(e);
    QT_VOID(
        static_cast<QPlainTextEdit*>(e)->setDocument(
        static_cast<QTextDocument*>(doc))
    );
}

extern "C" int qt_text_document_is_modified(void* doc) {
    QT_NULL_CHECK_RET(doc, 0);
    QT_RETURN(int, static_cast<QTextDocument*>(doc)->isModified() ? 1 : 0);
}

extern "C" void qt_text_document_set_modified(void* doc, int val) {
    QT_NULL_CHECK_VOID(doc);
    QT_VOID(static_cast<QTextDocument*>(doc)->setModified(val != 0));
}

// ============================================================
// QSyntaxHighlighter
// ============================================================

struct HighlightRule {
    QRegularExpression pattern;
    QTextCharFormat format;
};

struct MultiLineRule {
    QRegularExpression startPattern;
    QRegularExpression endPattern;
    QTextCharFormat format;
    int stateIndex;
};

class ConfigurableHighlighter : public QSyntaxHighlighter {
public:
    ConfigurableHighlighter(QTextDocument* parent)
        : QSyntaxHighlighter(parent), m_nextState(1) {}

    void addRule(const QString& pattern, const QTextCharFormat& fmt) {
        HighlightRule rule;
        rule.pattern = QRegularExpression(pattern);
        rule.format = fmt;
        m_rules.push_back(rule);
    }

    void addMultiLineRule(const QString& startPat, const QString& endPat,
                          const QTextCharFormat& fmt) {
        MultiLineRule rule;
        rule.startPattern = QRegularExpression(startPat);
        rule.endPattern = QRegularExpression(endPat);
        rule.format = fmt;
        rule.stateIndex = m_nextState++;
        m_multiLineRules.push_back(rule);
    }

    void clearRules() {
        m_rules.clear();
        m_multiLineRules.clear();
        m_nextState = 1;
    }

protected:
    void highlightBlock(const QString& text) override {
        // Apply single-line rules
        for (const auto& rule : m_rules) {
            auto it = rule.pattern.globalMatch(text);
            while (it.hasNext()) {
                auto match = it.next();
                setFormat(match.capturedStart(), match.capturedLength(),
                          rule.format);
            }
        }

        // Apply multi-line rules
        for (const auto& mlRule : m_multiLineRules) {
            int startIndex = 0;
            if (previousBlockState() != mlRule.stateIndex) {
                auto match = mlRule.startPattern.match(text);
                if (!match.hasMatch()) continue;
                startIndex = match.capturedStart();
            }

            while (startIndex >= 0) {
                int searchFrom = (previousBlockState() == mlRule.stateIndex
                                  && startIndex == 0)
                    ? 0
                    : startIndex + mlRule.startPattern.match(text, startIndex)
                                       .capturedLength();
                auto endMatch = mlRule.endPattern.match(text, searchFrom);
                int endIndex;
                int matchLength;

                if (!endMatch.hasMatch()) {
                    setCurrentBlockState(mlRule.stateIndex);
                    matchLength = text.length() - startIndex;
                } else {
                    endIndex = endMatch.capturedStart();
                    matchLength = endIndex - startIndex
                                  + endMatch.capturedLength();
                }

                setFormat(startIndex, matchLength, mlRule.format);

                if (!endMatch.hasMatch()) break;
                auto nextStart = mlRule.startPattern.match(
                    text, startIndex + matchLength);
                startIndex = nextStart.hasMatch()
                    ? nextStart.capturedStart() : -1;
            }
        }
    }

private:
    std::vector<HighlightRule> m_rules;
    std::vector<MultiLineRule> m_multiLineRules;
    int m_nextState;
};

static QTextCharFormat makeFormat(int r, int g, int b, int bold, int italic) {
    QTextCharFormat fmt;
    fmt.setForeground(QColor(r, g, b));
    if (bold) fmt.setFontWeight(QFont::Bold);
    if (italic) fmt.setFontItalic(true);
    return fmt;
}

extern "C" qt_syntax_highlighter_t qt_syntax_highlighter_create(void* document) {
    auto* doc = static_cast<QTextDocument*>(document);
    auto* h = new ConfigurableHighlighter(doc);
    QT_RETURN(qt_syntax_highlighter_t, static_cast<void*>(h));
}

extern "C" void qt_syntax_highlighter_destroy(qt_syntax_highlighter_t h) {
    QT_NULL_CHECK_VOID(h);
    QT_VOID(delete static_cast<ConfigurableHighlighter*>(h));
}

extern "C" void qt_syntax_highlighter_add_rule(qt_syntax_highlighter_t h,
    const char* pattern, int fg_r, int fg_g, int fg_b, int bold, int italic)
{
    QT_NULL_CHECK_VOID(h);
    QT_VOID(
        auto* hl = static_cast<ConfigurableHighlighter*>(h);
        hl->addRule(QString::fromUtf8(pattern), makeFormat(fg_r, fg_g, fg_b, bold, italic))
    );
}

extern "C" void qt_syntax_highlighter_add_keywords(qt_syntax_highlighter_t h,
    const char* keywords, int fg_r, int fg_g, int fg_b, int bold, int italic)
{
    QT_NULL_CHECK_VOID(h);
    QT_VOID(
        auto* hl = static_cast<ConfigurableHighlighter*>(h);
        // Split space-separated keywords and join with | for alternation
        QString kws = QString::fromUtf8(keywords);
        QStringList wordList = kws.split(' ', Qt::SkipEmptyParts);
        if (wordList.isEmpty()) return;
        // Escape special regex chars in each keyword, then join
        QStringList escaped;
        for (const auto& w : wordList) {
        escaped.append(QRegularExpression::escape(w));
        }
        QString pattern = "\\b(" + escaped.join("|") + ")\\b";
        hl->addRule(pattern, makeFormat(fg_r, fg_g, fg_b, bold, italic))
    );
}

extern "C" void qt_syntax_highlighter_add_multiline_rule(qt_syntax_highlighter_t h,
    const char* start_pattern, const char* end_pattern,
    int fg_r, int fg_g, int fg_b, int bold, int italic)
{
    QT_NULL_CHECK_VOID(h);
    QT_VOID(
        auto* hl = static_cast<ConfigurableHighlighter*>(h);
        hl->addMultiLineRule(QString::fromUtf8(start_pattern),
        QString::fromUtf8(end_pattern),
        makeFormat(fg_r, fg_g, fg_b, bold, italic))
    );
}

extern "C" void qt_syntax_highlighter_clear_rules(qt_syntax_highlighter_t h) {
    QT_NULL_CHECK_VOID(h);
    QT_VOID(static_cast<ConfigurableHighlighter*>(h)->clearRules());
}

extern "C" void qt_syntax_highlighter_rehighlight(qt_syntax_highlighter_t h) {
    QT_NULL_CHECK_VOID(h);
    QT_VOID(static_cast<ConfigurableHighlighter*>(h)->rehighlight());
}

// ============================================================
// Line Number Area
// ============================================================

// Helper to access protected QPlainTextEdit methods
class PlainTextEditAccess : public QPlainTextEdit {
public:
    using QPlainTextEdit::firstVisibleBlock;
    using QPlainTextEdit::blockBoundingGeometry;
    using QPlainTextEdit::blockBoundingRect;
    using QPlainTextEdit::contentOffset;
    using QPlainTextEdit::setViewportMargins;
};

static inline PlainTextEditAccess* pteAccess(QPlainTextEdit *e) {
    return static_cast<PlainTextEditAccess*>(e);
}

class LineNumberArea : public QWidget {
    QPlainTextEdit *editor;
    QColor bgColor{0x28, 0x28, 0x28};
    QColor fgColor{0x70, 0x70, 0x70};
public:
    LineNumberArea(QPlainTextEdit *e) : QWidget(e), editor(e) {
        updateWidth();
    }
    void setBgColor(int r, int g, int b) { bgColor = QColor(r, g, b); update(); }
    void setFgColor(int r, int g, int b) { fgColor = QColor(r, g, b); update(); }
    int areaWidth() const {
        int digits = 1;
        int mx = qMax(1, editor->blockCount());
        while (mx >= 10) { mx /= 10; ++digits; }
        int space = 6 + fontMetrics().horizontalAdvance(QLatin1Char('9')) * digits;
        return space;
    }
    void updateWidth() {
        int w = areaWidth();
        pteAccess(editor)->setViewportMargins(isVisible() ? w : 0, 0, 0, 0);
    }
    QSize sizeHint() const override { return QSize(areaWidth(), 0); }
protected:
    void paintEvent(QPaintEvent *event) override {
        QPainter painter(this);
        painter.fillRect(event->rect(), bgColor);
        painter.setPen(fgColor);
        auto *acc = pteAccess(editor);
        QTextBlock block = acc->firstVisibleBlock();
        int blockNumber = block.blockNumber();
        int top = qRound(acc->blockBoundingGeometry(block)
                         .translated(acc->contentOffset()).top());
        int bottom = top + qRound(acc->blockBoundingRect(block).height());
        while (block.isValid() && top <= event->rect().bottom()) {
            if (block.isVisible() && bottom >= event->rect().top()) {
                QString number = QString::number(blockNumber + 1);
                painter.drawText(0, top, width() - 3, fontMetrics().height(),
                                 Qt::AlignRight, number);
            }
            block = block.next();
            top = bottom;
            bottom = top + qRound(acc->blockBoundingRect(block).height());
            ++blockNumber;
        }
    }
};

extern "C" void* qt_line_number_area_create(qt_plain_text_edit_t editor) {
    void* _result = nullptr;
    auto _create = [&]() {
        auto* ed = static_cast<QPlainTextEdit*>(editor);
        auto* area = new LineNumberArea(ed);
        area->setFont(ed->font());
        // Connect signals for updating
        QObject::connect(ed, &QPlainTextEdit::blockCountChanged, area, [area](int) {
            area->updateWidth();
            area->update();
        });
        QObject::connect(ed, &QPlainTextEdit::updateRequest, area,
            [area](const QRect &rect, int dy) {
                if (dy) area->scroll(0, dy);
                else area->update(0, rect.y(), area->width(), rect.height());
            });
        area->updateWidth();
        area->show();
        _result = area;
    };
    if (is_qt_main_thread()) { _create(); }
    else { QMetaObject::invokeMethod(QCoreApplication::instance(), _create, Qt::BlockingQueuedConnection); }
    return _result;
}

extern "C" void qt_line_number_area_destroy(void* area) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(delete static_cast<LineNumberArea*>(area));
}

extern "C" void qt_line_number_area_set_visible(void* area, int visible) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(
        auto* a = static_cast<LineNumberArea*>(area);
        if (visible) a->show(); else a->hide();
        a->updateWidth()
    );
}

extern "C" void qt_line_number_area_set_bg_color(void* area, int r, int g, int b) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(static_cast<LineNumberArea*>(area)->setBgColor(r, g, b));
}

extern "C" void qt_line_number_area_set_fg_color(void* area, int r, int g, int b) {
    QT_NULL_CHECK_VOID(area);
    QT_VOID(static_cast<LineNumberArea*>(area)->setFgColor(r, g, b));
}

// ============================================================
// Extra Selections
// ============================================================

// Per-editor extra selection storage
#include <QHash>
static QHash<QPlainTextEdit*, QList<QTextEdit::ExtraSelection>> g_extraSelections;

// L1: Clean up extra selections when a widget is destroyed.
// Called from qt_widget_destroy — safe to call for non-QPlainTextEdit widgets (no-op).
static void qt_cleanup_extra_selections(void* w) {
    auto* ed = static_cast<QPlainTextEdit*>(w);
    g_extraSelections.remove(ed);
}

extern "C" void qt_plain_text_edit_clear_extra_selections(qt_plain_text_edit_t editor) {
    QT_NULL_CHECK_VOID(editor);
    QT_VOID(
        auto* ed = static_cast<QPlainTextEdit*>(editor);
        g_extraSelections[ed].clear()
    );
}

extern "C" void qt_plain_text_edit_add_extra_selection_line(qt_plain_text_edit_t editor,
    int line, int bg_r, int bg_g, int bg_b)
{
    QT_NULL_CHECK_VOID(editor);
    QT_VOID(
        auto* ed = static_cast<QPlainTextEdit*>(editor);
        QTextEdit::ExtraSelection sel;
        sel.format.setBackground(QColor(bg_r, bg_g, bg_b));
        sel.format.setProperty(QTextFormat::FullWidthSelection, true);
        QTextBlock block = ed->document()->findBlockByNumber(line);
        sel.cursor = QTextCursor(block);
        g_extraSelections[ed].append(sel)
    );
}

extern "C" void qt_plain_text_edit_add_extra_selection_range(qt_plain_text_edit_t editor,
    int start, int length, int fg_r, int fg_g, int fg_b,
    int bg_r, int bg_g, int bg_b, int bold)
{
    QT_NULL_CHECK_VOID(editor);
    QT_VOID(
        auto* ed = static_cast<QPlainTextEdit*>(editor);
        QTextEdit::ExtraSelection sel;
        sel.format.setForeground(QColor(fg_r, fg_g, fg_b));
        sel.format.setBackground(QColor(bg_r, bg_g, bg_b));
        if (bold) {
        sel.format.setFontWeight(QFont::Bold);
        }
        QTextCursor cursor(ed->document());
        cursor.setPosition(start);
        cursor.setPosition(start + length, QTextCursor::KeepAnchor);
        sel.cursor = cursor;
        g_extraSelections[ed].append(sel)
    );
}

extern "C" void qt_plain_text_edit_apply_extra_selections(qt_plain_text_edit_t editor) {
    QT_NULL_CHECK_VOID(editor);
    QT_VOID(
        auto* ed = static_cast<QPlainTextEdit*>(editor);
        ed->setExtraSelections(g_extraSelections[ed])
    );
}

// ============================================================
// Completer on QPlainTextEdit
// ============================================================

extern "C" void qt_completer_set_widget(void* completer, void* widget) {
    QT_NULL_CHECK_VOID(completer);
    QT_VOID(
        auto* c = static_cast<QCompleter*>(completer);
        c->setWidget(static_cast<QWidget*>(widget))
    );
}

extern "C" void qt_completer_complete_rect(void* completer, int x, int y, int w, int h) {
    QT_NULL_CHECK_VOID(completer);
    QT_VOID(
        auto* c = static_cast<QCompleter*>(completer);
        c->complete(QRect(x, y, w, h))
    );
}

// ============================================================
// Signal disconnect
// ============================================================

extern "C" void qt_disconnect_all(qt_widget_t obj) {
    QT_NULL_CHECK_VOID(obj);
    QT_VOID(
        if (obj) {
        static_cast<QObject*>(obj)->disconnect();
        }
    );
}

// ============================================================
// QScintilla (Scintilla-compatible editor widget)
// ============================================================

#ifdef QT_SCINTILLA_AVAILABLE

#include <Qsci/qsciscintilla.h>
#include <Qsci/qscilexer.h>
#include <Qsci/qscilexerbash.h>
#include <Qsci/qscilexercpp.h>
#include <Qsci/qscilexercss.h>
#include <Qsci/qscilexerhtml.h>
#include <Qsci/qscilexerjavascript.h>
#include <Qsci/qscilexerjson.h>
#include <Qsci/qscilexerlua.h>
#include <Qsci/qscilexermakefile.h>
#include <Qsci/qscilexermarkdown.h>
#include <Qsci/qscilexerpython.h>
#include <Qsci/qscilexerruby.h>
#include <Qsci/qscilexersql.h>
#include <Qsci/qscilexerxml.h>
#include <Qsci/qscilexeryaml.h>

// Thread-local buffer for receiving strings from Scintilla
static thread_local std::string s_sci_recv_buf;

// Helper: map language name to a QsciLexer instance
static QsciLexer* create_lexer_for_language(QsciScintilla* parent, const char* lang) {
    std::string l(lang);
    if (l == "bash" || l == "sh")     return new QsciLexerBash(parent);
    if (l == "cpp" || l == "c" || l == "c++") return new QsciLexerCPP(parent);
    if (l == "css")                   return new QsciLexerCSS(parent);
    if (l == "html")                  return new QsciLexerHTML(parent);
    if (l == "javascript" || l == "js") return new QsciLexerJavaScript(parent);
    if (l == "json")                  return new QsciLexerJSON(parent);
    if (l == "lua")                   return new QsciLexerLua(parent);
    if (l == "makefile" || l == "make") return new QsciLexerMakefile(parent);
    if (l == "markdown" || l == "md") return new QsciLexerMarkdown(parent);
    if (l == "python" || l == "py")   return new QsciLexerPython(parent);
    if (l == "ruby" || l == "rb")     return new QsciLexerRuby(parent);
    if (l == "sql")                   return new QsciLexerSQL(parent);
    if (l == "xml")                   return new QsciLexerXML(parent);
    if (l == "yaml" || l == "yml")    return new QsciLexerYAML(parent);
    return nullptr;  // no matching lexer
}

extern "C" qt_scintilla_t qt_scintilla_create(qt_widget_t parent) {
    qt_scintilla_t _result = nullptr;
    auto _create = [&]() {
        auto* p = parent ? static_cast<QWidget*>(parent) : nullptr;
        auto* sci = new QsciScintilla(p);
        sci->setUtf8(true);
        // Disable input method interaction to prevent Scintilla assertion crash.
        // Qt's input method framework (even with compose) calls inputMethodQuery()
        // which queries Qt::ImSurroundingText via SCI_GETTEXTRANGE. When terminal
        // PTY output rapidly replaces document text, stale positions cause
        // cpMax > pdoc->Length() assertion failure at Editor.cpp:6096.
        sci->setAttribute(Qt::WA_InputMethodEnabled, false);
        _result = static_cast<qt_scintilla_t>(sci);
    };
    if (is_qt_main_thread()) { _create(); }
    else { QMetaObject::invokeMethod(QCoreApplication::instance(), _create, Qt::BlockingQueuedConnection); }
    return _result;
}

extern "C" void qt_scintilla_destroy(qt_scintilla_t sci) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(delete static_cast<QsciScintilla*>(sci));
}

// Text-modifying Scintilla messages that can trigger SCN_MODIFIED notifications.
// During these operations, the document may be transiently empty (e.g. SCI_SETTEXT
// does DeleteChars + InsertString). If SCN_MODIFIED fires in between, handlers
// (accessibility, input method) may call SCI_GETTEXTRANGE with stale positions,
// causing PLATFORM_ASSERT(cpMax <= pdoc->Length()) crash at Editor.cpp:6096.
// We suppress modification events during these messages to prevent the crash.
static bool is_text_modifying_msg(unsigned int msg) {
    switch (msg) {
        case QsciScintillaBase::SCI_SETTEXT:
        case QsciScintillaBase::SCI_REPLACESEL:
        case QsciScintillaBase::SCI_APPENDTEXT:
        case QsciScintillaBase::SCI_INSERTTEXT:
        case QsciScintillaBase::SCI_CLEARALL:
        case QsciScintillaBase::SCI_DELETERANGE:
        case QsciScintillaBase::SCI_ADDTEXT:
        case QsciScintillaBase::SCI_REPLACETARGET:
        case QsciScintillaBase::SCI_REPLACETARGETRE:
            return true;
        default:
            return false;
    }
}

extern "C" long qt_scintilla_send_message(qt_scintilla_t sci, unsigned int msg,
                                          unsigned long wparam, long lparam) {
    auto* s = static_cast<QsciScintilla*>(sci);
    if (is_text_modifying_msg(msg)) {
        // Disable updates to prevent sendPostedEvents from processing a
        // repaint mid-modification when called via BlockingQueuedConnection.
        // QT_VOID uses [=] capture (const), so we dispatch manually with [&].
        auto do_op = [&]() -> long {
            s->setUpdatesEnabled(false);
            long old_mask = s->SendScintilla(QsciScintillaBase::SCI_GETMODEVENTMASK);
            s->SendScintilla(QsciScintillaBase::SCI_SETMODEVENTMASK, 0L);
            long r = s->SendScintilla(msg, wparam, lparam);
            s->SendScintilla(QsciScintillaBase::SCI_SETMODEVENTMASK, old_mask);
            s->setUpdatesEnabled(true);
            return r;
        };
        if (is_qt_main_thread()) { return do_op(); }
        char fn_buf[64];
        snprintf(fn_buf, sizeof(fn_buf), "qt_scintilla_send_message(sci,msg=%u)", msg);
        vlog_bqc_enter(fn_buf);
        long result = 0;
        QMetaObject::invokeMethod(QCoreApplication::instance(),
            [&]() { result = do_op(); }, Qt::BlockingQueuedConnection);
        vlog_bqc_exit(fn_buf);
        return result;
    }
    QT_RETURN(long, s->SendScintilla(msg, wparam, lparam));
}

extern "C" long qt_scintilla_send_message_string(qt_scintilla_t sci, unsigned int msg,
                                                 unsigned long wparam, const char* str) {
    auto* s = static_cast<QsciScintilla*>(sci);
    if (is_text_modifying_msg(msg)) {
        // Disable updates to prevent sendPostedEvents from processing a
        // repaint mid-modification when called via BlockingQueuedConnection.
        // QT_VOID uses [=] capture (const), so we dispatch manually with [&].
        auto do_op = [&]() -> long {
            s->setUpdatesEnabled(false);
            long old_mask = s->SendScintilla(QsciScintillaBase::SCI_GETMODEVENTMASK);
            s->SendScintilla(QsciScintillaBase::SCI_SETMODEVENTMASK, 0L);
            long r = s->SendScintilla(msg, wparam, reinterpret_cast<long>(str));
            s->SendScintilla(QsciScintillaBase::SCI_SETMODEVENTMASK, old_mask);
            s->setUpdatesEnabled(true);
            return r;
        };
        if (is_qt_main_thread()) { return do_op(); }
        char fn_buf[64];
        snprintf(fn_buf, sizeof(fn_buf), "qt_scintilla_send_message_string(msg=%u)", msg);
        vlog_bqc_enter(fn_buf);
        long result = 0;
        QMetaObject::invokeMethod(QCoreApplication::instance(),
            [&]() { result = do_op(); }, Qt::BlockingQueuedConnection);
        vlog_bqc_exit(fn_buf);
        return result;
    }
    QT_RETURN(long, s->SendScintilla(msg, wparam, reinterpret_cast<long>(str)));
}

extern "C" const char* qt_scintilla_receive_string(qt_scintilla_t sci, unsigned int msg,
                                                   unsigned long wparam) {
    QT_NULL_CHECK_RET(sci, "");
    auto* s = static_cast<QsciScintilla*>(sci);
    QT_VOID(
        // First call: get length (lparam=0 means "return length needed")
        long len = s->SendScintilla(msg, wparam, static_cast<long>(0));
        if (len <= 0) {
            s_sci_recv_buf.clear();
        } else {
            s_sci_recv_buf.resize(len + 1, '\0');
            // Second call: fill buffer
            s->SendScintilla(msg, wparam, reinterpret_cast<long>(s_sci_recv_buf.data()));
            s_sci_recv_buf[len] = '\0';
        };
        s_return_buf = s_sci_recv_buf
    );
    return s_return_buf.c_str();
}

// Set UTF-8 mode on a QsciScintilla widget using setUtf8() — the authoritative
// QsciScintilla API for encoding, as opposed to raw SCI_SETCODEPAGE.
extern "C" void qt_scintilla_set_utf8(qt_scintilla_t sci, int enable) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(static_cast<QsciScintilla*>(sci)->setUtf8(enable != 0));
}

extern "C" void qt_scintilla_set_text(qt_scintilla_t sci, const char* text) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        bool ro = s->isReadOnly();
        // Disable widget updates during text replacement.  When called via
        // BlockingQueuedConnection (from a Gambit VP thread), Qt's
        // sendPostedEvents loop can process a repaint event posted by
        // SCI_SETTEXT while QScintilla is still in an intermediate state
        // (document partially modified), causing a crash in the paint path.
        // setUpdatesEnabled(false) prevents any update() calls from posting
        // paint events until we re-enable at the end with a consistent state.
        s->setUpdatesEnabled(false);
        if (ro) s->SendScintilla(QsciScintillaBase::SCI_SETREADONLY, 0L);
        // Suppress SCN_MODIFIED during text replacement to prevent handlers
        // from calling SCI_GETTEXTRANGE with stale positions.
        long old_mask = s->SendScintilla(QsciScintillaBase::SCI_GETMODEVENTMASK);
        s->SendScintilla(QsciScintillaBase::SCI_SETMODEVENTMASK, 0L);
        s->SendScintilla(QsciScintillaBase::SCI_SETTEXT, text);
        s->SendScintilla(QsciScintillaBase::SCI_SETMODEVENTMASK, old_mask);
        s->SendScintilla(QsciScintillaBase::SCI_EMPTYUNDOBUFFER);
        if (ro) s->SendScintilla(QsciScintillaBase::SCI_SETREADONLY, 1L);
        // Re-enable updates now that the document is fully consistent.
        // This posts an update() which schedules an async repaint.
        s->setUpdatesEnabled(true)
    );
}

extern "C" const char* qt_scintilla_get_text(qt_scintilla_t sci) {
    QT_NULL_CHECK_RET(sci, "");
    QT_RETURN_STRING(static_cast<QsciScintilla*>(sci)->text().toUtf8().constData());
}

extern "C" int qt_scintilla_get_text_length(qt_scintilla_t sci) {
    QT_NULL_CHECK_RET(sci, 0);
    QT_RETURN(int, static_cast<QsciScintilla*>(sci)->text().toUtf8().length());
}

// Helper: convert Scintilla BGR color int to QColor
static QColor sci_to_qcolor(int color) {
    return QColor(color & 0xFF, (color >> 8) & 0xFF, (color >> 16) & 0xFF);
}

extern "C" void qt_scintilla_set_lexer_language(qt_scintilla_t sci, const char* language) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        // Delete old lexer if any
        QsciLexer* old = s->lexer();
        QsciLexer* lex = create_lexer_for_language(s, language);
        s->setLexer(lex);  // nullptr disables lexer
        delete old;
        // After setLexer, override paper (background) to dark theme.
        // QsciLexer defaults are light-themed; this makes them dark.
        // Foreground colors from the lexer subclass are kept as-is
        // since most are already distinct (blue, green, red, etc).
        if (lex) {
            QColor dark_bg(0x1e, 0x1e, 0x2e);
            lex->setPaper(dark_bg, -1);
            lex->setDefaultPaper(dark_bg);
            // Brighten default text for dark background
            lex->setDefaultColor(QColor(0xcd, 0xd6, 0xf4));
            lex->setColor(QColor(0xcd, 0xd6, 0xf4), -1);
            // Apply Catppuccin Mocha-inspired dark theme colors per style.
            // These apply generically to all QsciLexer subclasses since
            // style IDs 0-15 are common across most lexers.
            // Style 0: Default text
            lex->setColor(QColor(0xcd, 0xd6, 0xf4), 0);
            // Style 1: Comments (green)
            lex->setColor(QColor(0xa6, 0xe3, 0xa1), 1);
            // Style 2: Numbers / line numbers (peach)
            lex->setColor(QColor(0xfa, 0xb3, 0x87), 2);
            // Style 3: Strings / single-quoted (yellow)
            lex->setColor(QColor(0xf9, 0xe2, 0xaf), 3);
            // Style 4: Keywords / operators (mauve)
            lex->setColor(QColor(0xcb, 0xa6, 0xf7), 4);
            // Style 5: Variables / identifiers (blue)
            lex->setColor(QColor(0x89, 0xb4, 0xfa), 5);
            // Style 6: Backtick strings / here-docs (teal)
            lex->setColor(QColor(0x94, 0xe2, 0xd5), 6);
            // Style 7: Operators / param expansion (flamingo)
            lex->setColor(QColor(0xf2, 0xcd, 0xcd), 7);
            // Style 8: Heredoc delimiter (maroon)
            lex->setColor(QColor(0xeb, 0xa0, 0xac), 8);
            // Style 9: Scalar variable (sapphire)
            lex->setColor(QColor(0x74, 0xc7, 0xec), 9);
            // Style 10: Error / special (red)
            lex->setColor(QColor(0xf3, 0x8b, 0xa8), 10);
            // Style 11: Preprocessor / here-doc body (sky)
            lex->setColor(QColor(0x89, 0xdc, 0xeb), 11);
            // Style 12: Double-quoted string (yellow, same as 3)
            lex->setColor(QColor(0xf9, 0xe2, 0xaf), 12);
            // Style 13: Regex (pink)
            lex->setColor(QColor(0xf5, 0xc2, 0xe7), 13);
        }
    );
}

// Set lexer language AND apply dark theme colors in one call.
// fg/bg are Scintilla BGR color ints. style_pairs is "style:color,style:color,..."
// where each style is an int and color is a hex BGR value.
// This avoids the need for separate FFI functions that require symbol registration.
extern "C" void qt_scintilla_set_lexer_with_theme(qt_scintilla_t sci, const char* language,
                                                    int default_fg, int default_bg,
                                                    const char* style_spec) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        QsciLexer* old = s->lexer();
        QsciLexer* lex = create_lexer_for_language(s, language);
        // Set lexer first (this applies the lexer's default light-theme colors)
        s->setLexer(lex);
        delete old;
        // NOW override colors on the active lexer — after setLexer() has connected signals
        if (lex) {
            QColor bg = sci_to_qcolor(default_bg);
            QColor fg = sci_to_qcolor(default_fg);
            // Set default paper/color for ALL styles (style -1)
            lex->setPaper(bg, -1);
            lex->setColor(fg, -1);
            // Also set the default paper explicitly for STYLE_DEFAULT
            lex->setDefaultPaper(bg);
            lex->setDefaultColor(fg);
            // Parse style spec: "style:color:bold:italic,..."
            if (style_spec && style_spec[0]) {
                std::string spec(style_spec);
                size_t pos = 0;
                while (pos < spec.size()) {
                    size_t comma = spec.find(',', pos);
                    if (comma == std::string::npos) comma = spec.size();
                    std::string entry = spec.substr(pos, comma - pos);
                    int style_id = 0, color = 0, bold = 0, italic = 0;
                    if (sscanf(entry.c_str(), "%d:%x:%d:%d", &style_id, &color, &bold, &italic) >= 2) {
                        lex->setColor(sci_to_qcolor(color), style_id);
                        if (bold || italic) {
                            QFont f = lex->font(style_id);
                            if (bold) f.setBold(true);
                            if (italic) f.setItalic(true);
                            lex->setFont(f, style_id);
                        }
                    }
                    pos = comma + 1;
                }
            }
        }
        // Also set via Scintilla API as fallback for areas not covered by lexer
        s->SendScintilla(QsciScintillaBase::SCI_STYLESETBACK,
                         QsciScintillaBase::STYLE_DEFAULT, (long)default_bg);
        s->SendScintilla(QsciScintillaBase::SCI_STYLESETFORE,
                         QsciScintillaBase::STYLE_DEFAULT, (long)default_fg);
        s->SendScintilla(QsciScintillaBase::SCI_STYLECLEARALL);
        // Re-apply per-style colors via lexer (STYLECLEARALL wiped them)
        if (lex) {
            QColor bg = sci_to_qcolor(default_bg);
            QColor fg = sci_to_qcolor(default_fg);
            lex->setPaper(bg, -1);
            lex->setColor(fg, -1);
            if (style_spec && style_spec[0]) {
                std::string spec(style_spec);
                size_t pos = 0;
                while (pos < spec.size()) {
                    size_t comma = spec.find(',', pos);
                    if (comma == std::string::npos) comma = spec.size();
                    std::string entry = spec.substr(pos, comma - pos);
                    int style_id = 0, color = 0, bold = 0, italic = 0;
                    if (sscanf(entry.c_str(), "%d:%x:%d:%d", &style_id, &color, &bold, &italic) >= 2) {
                        lex->setColor(sci_to_qcolor(color), style_id);
                        if (bold || italic) {
                            QFont f = lex->font(style_id);
                            if (bold) f.setBold(true);
                            if (italic) f.setItalic(true);
                            lex->setFont(f, style_id);
                        }
                    }
                    pos = comma + 1;
                }
            }
        }
        // Force re-colorize
        s->SendScintilla(QsciScintillaBase::SCI_COLOURISE, (unsigned long)0, (long)-1)
    );
}

extern "C" void qt_scintilla_lexer_set_color(qt_scintilla_t sci, int style, int color) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* lex = static_cast<QsciScintilla*>(sci)->lexer();
        if (lex) {
            int r = color & 0xFF;
            int g = (color >> 8) & 0xFF;
            int b = (color >> 16) & 0xFF;
            lex->setColor(QColor(r, g, b), style);
        }
    );
}

extern "C" void qt_scintilla_lexer_set_paper(qt_scintilla_t sci, int style, int color) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* lex = static_cast<QsciScintilla*>(sci)->lexer();
        if (lex) {
            int r = color & 0xFF;
            int g = (color >> 8) & 0xFF;
            int b = (color >> 16) & 0xFF;
            lex->setPaper(QColor(r, g, b), style);
        }
    );
}

extern "C" void qt_scintilla_lexer_set_font_attr(qt_scintilla_t sci, int style, int bold, int italic) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* lex = static_cast<QsciScintilla*>(sci)->lexer();
        if (lex) {
            QFont f = lex->font(style);
            f.setBold(bold != 0);
            f.setItalic(italic != 0);
            lex->setFont(f, style);
        }
    );
}

extern "C" const char* qt_scintilla_get_lexer_language(qt_scintilla_t sci) {
    QT_NULL_CHECK_RET(sci, "");
    auto* lex = static_cast<QsciScintilla*>(sci)->lexer();
    if (!lex) {
    } else {
        s_return_buf = lex->language();
    }
    QT_RETURN_STRING("");
}

extern "C" void qt_scintilla_set_read_only(qt_scintilla_t sci, int read_only) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(static_cast<QsciScintilla*>(sci)->setReadOnly(read_only != 0));
}

extern "C" int qt_scintilla_is_read_only(qt_scintilla_t sci) {
    QT_NULL_CHECK_RET(sci, 0);
    QT_RETURN(int, static_cast<QsciScintilla*>(sci)->isReadOnly() ? 1 : 0);
}

extern "C" void qt_scintilla_set_margin_width(qt_scintilla_t sci, int margin, int width) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(static_cast<QsciScintilla*>(sci)->setMarginWidth(margin, width));
}

extern "C" void qt_scintilla_set_margin_type(qt_scintilla_t sci, int margin, int type) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        static_cast<QsciScintilla*>(sci)->setMarginType(
        margin, static_cast<QsciScintilla::MarginType>(type))
    );
}

extern "C" void qt_scintilla_set_focus(qt_scintilla_t sci) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(static_cast<QsciScintilla*>(sci)->setFocus());
}

// Signal connections
extern "C" void qt_scintilla_on_text_changed(qt_scintilla_t sci,
                                             qt_callback_void callback,
                                             long callback_id) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        QObject::connect(s, &QsciScintilla::textChanged, [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_scintilla_on_char_added(qt_scintilla_t sci,
                                           qt_callback_int callback,
                                           long callback_id) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        // QScintilla uses SCN_CHARADDED signal
        QObject::connect(s, &QsciScintilla::SCN_CHARADDED, [callback, callback_id](int ch) {
        callback(callback_id, ch);
        })
    );
}

extern "C" void qt_scintilla_on_save_point_reached(qt_scintilla_t sci,
                                                   qt_callback_void callback,
                                                   long callback_id) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        QObject::connect(s, &QsciScintilla::SCN_SAVEPOINTREACHED, [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_scintilla_on_save_point_left(qt_scintilla_t sci,
                                                qt_callback_void callback,
                                                long callback_id) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        QObject::connect(s, &QsciScintilla::SCN_SAVEPOINTLEFT, [callback, callback_id]() {
        callback(callback_id);
        })
    );
}

extern "C" void qt_scintilla_on_margin_clicked(qt_scintilla_t sci,
                                               qt_callback_int callback,
                                               long callback_id) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        QObject::connect(s, &QsciScintilla::marginClicked,
        [callback, callback_id](int margin, int line, Qt::KeyboardModifiers) {
        // L3: Pack margin in bits 24-31, line in bits 0-23 (supports up to 16M lines)
        callback(callback_id, (margin << 24) | (line & 0xFFFFFF));
        })
    );
}

extern "C" void qt_scintilla_on_modified(qt_scintilla_t sci,
                                         qt_callback_int callback,
                                         long callback_id) {
    QT_NULL_CHECK_VOID(sci);
    QT_VOID(
        auto* s = static_cast<QsciScintilla*>(sci);
        QObject::connect(s, &QsciScintilla::modificationChanged,
        [callback, callback_id](bool modified) {
        callback(callback_id, modified ? 1 : 0);
        })
    );
}

#endif /* QT_SCINTILLA_AVAILABLE */

// ============================================================================
// QTerminalWidget — proper VT100 terminal emulator using libvterm + QPainter
//
// A self-contained terminal widget that:
//   - Owns a PTY (via forkpty) and spawns a child shell/command
//   - Uses libvterm for VT100/xterm-256color terminal emulation
//   - Renders cell-by-cell with QPainter (proper fg/bg colors, bold, etc.)
//   - Handles keyboard input internally (keyPressEvent → libvterm → PTY)
//   - Polls PTY output via QTimer → libvterm → damage → repaint
//   - Resizes terminal on widget resize (TIOCSWINSZ + vterm_set_size)
// ============================================================================

#include <vterm.h>
#include <pty.h>
#include <termios.h>
#include <sys/ioctl.h>

// Forward declaration for VTermScreenCallbacks (C++17 doesn't allow
// designated initializers, so we initialize fields explicitly).
static VTermScreenCallbacks s_term_screen_cbs;
static bool s_term_cbs_initialized = false;

class QTerminalWidget : public QWidget {
public:
    VTerm*        m_vt         = nullptr;
    VTermScreen*  m_screen     = nullptr;
    int           m_master_fd  = -1;
    pid_t         m_child_pid  = -1;
    int           m_rows       = 24;
    int           m_cols       = 80;
    int           m_cursor_row = 0;
    int           m_cursor_col = 0;
    bool          m_cursor_visible = true;
    bool          m_running    = false;
    QFont         m_font;
    int           m_cell_w     = 8;
    int           m_cell_h     = 16;
    int           m_cell_asc   = 13;
    QTimer*       m_timer      = nullptr;
    QColor        m_default_fg;
    QColor        m_default_bg;

    // ── VTerm screen callbacks (static — use void* user to find widget) ────

    static int cb_damage(VTermRect rect, void* user) {
        auto* w = static_cast<QTerminalWidget*>(user);
        int x  = rect.start_col * w->m_cell_w;
        int y  = rect.start_row * w->m_cell_h;
        int rw = (rect.end_col - rect.start_col) * w->m_cell_w;
        int rh = (rect.end_row - rect.start_row) * w->m_cell_h;
        w->update(x, y, rw, rh);
        return 0;
    }

    static int cb_movecursor(VTermPos pos, VTermPos oldpos, int visible, void* user) {
        auto* w = static_cast<QTerminalWidget*>(user);
        w->m_cursor_row = pos.row;
        w->m_cursor_col = pos.col;
        w->m_cursor_visible = visible;
        w->update(oldpos.col * w->m_cell_w, oldpos.row * w->m_cell_h,
                  w->m_cell_w, w->m_cell_h);
        w->update(pos.col * w->m_cell_w, pos.row * w->m_cell_h,
                  w->m_cell_w, w->m_cell_h);
        return 0;
    }

    static int cb_bell(void* user) { (void)user; return 0; }

    static int cb_resize(int rows, int cols, void* user) {
        (void)rows; (void)cols; (void)user; return 1;
    }

    static int cb_settermprop(VTermProp prop, VTermValue* val, void* user) {
        (void)prop; (void)val; (void)user; return 1;
    }

    static int cb_sb_pushline(int cols, const VTermScreenCell* cells, void* user) {
        (void)cols; (void)cells; (void)user; return 0; // discard scrollback for now
    }

    static int cb_sb_popline(int cols, VTermScreenCell* cells, void* user) {
        (void)cols; (void)cells; (void)user; return 0;
    }

    // ── Constructor / Destructor ───────────────────────────────────────────

    explicit QTerminalWidget(QWidget* parent = nullptr)
        : QWidget(parent)
        , m_default_fg(0xC0, 0xC0, 0xC0)
        , m_default_bg(0x18, 0x18, 0x18)
    {
        setFocusPolicy(Qt::StrongFocus);
        setAttribute(Qt::WA_OpaquePaintEvent, true);

        m_font = QFont("DejaVu Sans Mono", 11);
        m_font.setStyleHint(QFont::Monospace);
        computeCellSize();

        initVterm();

        m_timer = new QTimer(this);
        QObject::connect(m_timer, &QTimer::timeout, [this]() { pollPty(); });
    }

    ~QTerminalWidget() override {
        if (m_timer) m_timer->stop();
        cleanupPty();
        if (m_vt) { vterm_free(m_vt); m_vt = nullptr; }
    }

    // Public alias so qt_terminal_destroy can call PTY cleanup before
    // the widget is actually deleted (via deleteLater).
    void cleanupPtyPublic() { cleanupPty(); }

    // ── libvterm initialization ────────────────────────────────────────────

    void initVterm() {
        if (m_vt) vterm_free(m_vt);

        m_vt = vterm_new(m_rows, m_cols);
        vterm_set_utf8(m_vt, 1);
        m_screen = vterm_obtain_screen(m_vt);

        // Initialize callbacks struct once
        if (!s_term_cbs_initialized) {
            memset(&s_term_screen_cbs, 0, sizeof(s_term_screen_cbs));
            s_term_screen_cbs.damage      = cb_damage;
            s_term_screen_cbs.movecursor  = cb_movecursor;
            s_term_screen_cbs.settermprop = cb_settermprop;
            s_term_screen_cbs.bell        = cb_bell;
            s_term_screen_cbs.resize      = cb_resize;
            s_term_screen_cbs.sb_pushline = cb_sb_pushline;
            s_term_screen_cbs.sb_popline  = cb_sb_popline;
            s_term_cbs_initialized = true;
        }

        vterm_screen_set_callbacks(m_screen, &s_term_screen_cbs, this);
        vterm_screen_enable_altscreen(m_screen, 1);
        vterm_screen_set_damage_merge(m_screen, VTERM_DAMAGE_SCROLL);
        vterm_screen_reset(m_screen, 1);
    }

    // ── Font / cell metrics ────────────────────────────────────────────────

    void computeCellSize() {
        QFontMetrics fm(m_font);
        m_cell_w   = fm.horizontalAdvance('M');
        m_cell_h   = fm.height();
        m_cell_asc = fm.ascent();
        if (m_cell_w <= 0) m_cell_w = 8;
        if (m_cell_h <= 0) m_cell_h = 16;
    }

    void setTermFont(const char* family, int size) {
        m_font = QFont(QString::fromUtf8(family), size);
        m_font.setStyleHint(QFont::Monospace);
        computeCellSize();
        updateTermSize();
        update();
    }

    // ── PTY spawn / cleanup ────────────────────────────────────────────────

    void spawnShell(const char* cmd) {
        if (m_running) return;

        struct winsize ws;
        ws.ws_row    = m_rows;
        ws.ws_col    = m_cols;
        ws.ws_xpixel = m_cols * m_cell_w;
        ws.ws_ypixel = m_rows * m_cell_h;

        int master_fd = -1;
        pid_t pid = forkpty(&master_fd, nullptr, nullptr, &ws);
        if (pid < 0) return;

        if (pid == 0) {
            // ── Child process ──
            setenv("TERM", "xterm-256color", 1);
            setenv("COLORTERM", "truecolor", 1);

            if (cmd && cmd[0]) {
                execl("/bin/sh", "sh", "-c", cmd, nullptr);
            } else {
                const char* shell = getenv("SHELL");
                if (!shell) shell = "/bin/sh";
                execl(shell, shell, "-l", nullptr);
            }
            _exit(127);
        }

        // ── Parent ──
        m_master_fd = master_fd;
        m_child_pid = pid;
        m_running   = true;

        // Non-blocking reads
        int flags = fcntl(m_master_fd, F_GETFL, 0);
        fcntl(m_master_fd, F_SETFL, flags | O_NONBLOCK);

        m_timer->start(10); // poll every 10ms
    }

    void cleanupPty() {
        if (m_timer) m_timer->stop();
        if (m_child_pid > 0) {
            // Close master fd first — this sends SIGHUP to the child, which
            // is gentler than SIGTERM and causes most shells to exit.
            if (m_master_fd >= 0) {
                ::close(m_master_fd);
                m_master_fd = -1;
            }
            // Non-blocking check — child may have already exited on SIGHUP.
            int status;
            pid_t result = waitpid(m_child_pid, &status, WNOHANG);
            if (result != m_child_pid) {
                // Child still alive — escalate to SIGTERM then SIGKILL.
                kill(m_child_pid, SIGTERM);
                // Poll for up to 200ms with WNOHANG before giving up.
                for (int i = 0; i < 20 && result != m_child_pid; ++i) {
                    struct timespec ts = {0, 10000000}; // 10ms
                    nanosleep(&ts, nullptr);
                    result = waitpid(m_child_pid, &status, WNOHANG);
                }
                if (result != m_child_pid) {
                    kill(m_child_pid, SIGKILL);
                    // One final non-blocking reap; orphan if still alive.
                    waitpid(m_child_pid, &status, WNOHANG);
                }
            }
            m_child_pid = -1;
        }
        if (m_master_fd >= 0) {
            ::close(m_master_fd);
            m_master_fd = -1;
        }
        m_running = false;
    }

    // ── Input to PTY ───────────────────────────────────────────────────────

    void sendInput(const char* data, int len) {
        if (m_master_fd >= 0 && len > 0) {
            ::write(m_master_fd, data, len);
        }
    }

    void interruptChild() {
        if (m_master_fd >= 0 && m_child_pid > 0) {
            kill(m_child_pid, SIGINT);
        }
    }

    bool isRunning() const { return m_running; }

protected:
    // ── Painting ───────────────────────────────────────────────────────────

    void paintEvent(QPaintEvent* ev) override {
        QPainter p(this);
        p.setFont(m_font);

        QRect r = ev->rect();
        int start_row = r.top()    / m_cell_h;
        int end_row   = std::min(m_rows, r.bottom()  / m_cell_h + 1);
        int start_col = r.left()   / m_cell_w;
        int end_col   = std::min(m_cols, r.right()   / m_cell_w + 1);

        for (int row = start_row; row < end_row; row++) {
            for (int col = start_col; col < end_col; col++) {
                VTermPos pos = { row, col };
                VTermScreenCell cell;
                vterm_screen_get_cell(m_screen, pos, &cell);

                // Resolve colors
                QColor fg = m_default_fg, bg = m_default_bg;

                if (!VTERM_COLOR_IS_DEFAULT_FG(&cell.fg)) {
                    VTermColor c = cell.fg;
                    if (VTERM_COLOR_IS_INDEXED(&c))
                        vterm_screen_convert_color_to_rgb(m_screen, &c);
                    fg = QColor(c.rgb.red, c.rgb.green, c.rgb.blue);
                }
                if (!VTERM_COLOR_IS_DEFAULT_BG(&cell.bg)) {
                    VTermColor c = cell.bg;
                    if (VTERM_COLOR_IS_INDEXED(&c))
                        vterm_screen_convert_color_to_rgb(m_screen, &c);
                    bg = QColor(c.rgb.red, c.rgb.green, c.rgb.blue);
                }

                if (cell.attrs.reverse) std::swap(fg, bg);
                if (cell.attrs.bold)    fg = fg.lighter(150);

                int x = col * m_cell_w;
                int y = row * m_cell_h;
                int cw = m_cell_w * (cell.width > 0 ? cell.width : 1);

                // Background
                p.fillRect(x, y, cw, m_cell_h, bg);

                // Character
                if (cell.chars[0] != 0) {
                    QFont df = m_font;
                    if (cell.attrs.bold)   df.setBold(true);
                    if (cell.attrs.italic) df.setItalic(true);
                    if (cell.attrs.bold || cell.attrs.italic) p.setFont(df);
                    p.setPen(fg);

                    QString ch = QString::fromUcs4(&cell.chars[0], 1);
                    p.drawText(x, y + m_cell_asc, ch);

                    if (cell.attrs.bold || cell.attrs.italic) p.setFont(m_font);
                }

                // Underline
                if (cell.attrs.underline) {
                    p.setPen(fg);
                    p.drawLine(x, y + m_cell_h - 1, x + cw - 1, y + m_cell_h - 1);
                }

                // Strikethrough
                if (cell.attrs.strike) {
                    p.setPen(fg);
                    p.drawLine(x, y + m_cell_h / 2, x + cw - 1, y + m_cell_h / 2);
                }

                // Skip right half of wide characters
                if (cell.width > 1) col += cell.width - 1;
            }
        }

        // Cursor
        if (m_cursor_visible && m_cursor_row >= start_row && m_cursor_row < end_row
            && m_cursor_col >= start_col && m_cursor_col < end_col) {
            int cx = m_cursor_col * m_cell_w;
            int cy = m_cursor_row * m_cell_h;
            if (hasFocus()) {
                p.setCompositionMode(QPainter::CompositionMode_Difference);
                p.fillRect(cx, cy, m_cell_w, m_cell_h, Qt::white);
                p.setCompositionMode(QPainter::CompositionMode_SourceOver);
            } else {
                p.setPen(m_default_fg);
                p.drawRect(cx, cy, m_cell_w - 1, m_cell_h - 1);
            }
        }

        // Fill unused area beyond terminal grid
        int term_w = m_cols * m_cell_w;
        int term_h = m_rows * m_cell_h;
        if (width() > term_w)
            p.fillRect(term_w, 0, width() - term_w, height(), m_default_bg);
        if (height() > term_h)
            p.fillRect(0, term_h, width(), height() - term_h, m_default_bg);
    }

public:
    // ── Public key forwarding ────────────────────────────────────────────
    //
    // Called from qt_terminal_send_key_event() when the jemacs key handler
    // forwards a non-command key to the terminal widget.

    void handleKeyEvent(int key, int modifiers, const QString& text) {
        QKeyEvent ev(QEvent::KeyPress,
                     static_cast<Qt::Key>(key),
                     static_cast<Qt::KeyboardModifiers>(modifiers),
                     text);
        keyPressEvent(&ev);
    }

protected:
    // ── Keyboard input ─────────────────────────────────────────────────────

    void keyPressEvent(QKeyEvent* ev) override {
        if (!m_vt || m_master_fd < 0) return;

        VTermModifier mod = VTERM_MOD_NONE;
        if (ev->modifiers() & Qt::ShiftModifier)   mod = (VTermModifier)(mod | VTERM_MOD_SHIFT);
        if (ev->modifiers() & Qt::AltModifier)     mod = (VTermModifier)(mod | VTERM_MOD_ALT);
        if (ev->modifiers() & Qt::ControlModifier) mod = (VTermModifier)(mod | VTERM_MOD_CTRL);

        VTermKey vtkey = VTERM_KEY_NONE;
        switch (ev->key()) {
            case Qt::Key_Return:    case Qt::Key_Enter: vtkey = VTERM_KEY_ENTER;     break;
            case Qt::Key_Backspace:                     vtkey = VTERM_KEY_BACKSPACE;  break;
            case Qt::Key_Escape:                        vtkey = VTERM_KEY_ESCAPE;     break;
            case Qt::Key_Tab:                           vtkey = VTERM_KEY_TAB;        break;
            case Qt::Key_Up:                            vtkey = VTERM_KEY_UP;         break;
            case Qt::Key_Down:                          vtkey = VTERM_KEY_DOWN;       break;
            case Qt::Key_Left:                          vtkey = VTERM_KEY_LEFT;       break;
            case Qt::Key_Right:                         vtkey = VTERM_KEY_RIGHT;      break;
            case Qt::Key_Insert:                        vtkey = VTERM_KEY_INS;        break;
            case Qt::Key_Delete:                        vtkey = VTERM_KEY_DEL;        break;
            case Qt::Key_Home:                          vtkey = VTERM_KEY_HOME;       break;
            case Qt::Key_End:                           vtkey = VTERM_KEY_END;        break;
            case Qt::Key_PageUp:                        vtkey = VTERM_KEY_PAGEUP;     break;
            case Qt::Key_PageDown:                      vtkey = VTERM_KEY_PAGEDOWN;   break;
            case Qt::Key_F1:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  1); break;
            case Qt::Key_F2:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  2); break;
            case Qt::Key_F3:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  3); break;
            case Qt::Key_F4:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  4); break;
            case Qt::Key_F5:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  5); break;
            case Qt::Key_F6:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  6); break;
            case Qt::Key_F7:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  7); break;
            case Qt::Key_F8:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  8); break;
            case Qt::Key_F9:  vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 +  9); break;
            case Qt::Key_F10: vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 + 10); break;
            case Qt::Key_F11: vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 + 11); break;
            case Qt::Key_F12: vtkey = (VTermKey)(VTERM_KEY_FUNCTION_0 + 12); break;
            default: break;
        }

        bool handled = false;
        if (vtkey != VTERM_KEY_NONE) {
            vterm_keyboard_key(m_vt, vtkey, mod);
            handled = true;
        } else if (!ev->text().isEmpty()) {
            QString text = ev->text();
            for (int i = 0; i < text.size(); i++) {
                uint32_t cp = text.at(i).unicode();
                if (QChar::isHighSurrogate(cp) && i + 1 < text.size()) {
                    uint32_t lo = text.at(i + 1).unicode();
                    if (QChar::isLowSurrogate(lo)) {
                        cp = QChar::surrogateToUcs4(cp, lo);
                        i++;
                    }
                }
                vterm_keyboard_unichar(m_vt, cp, mod);
            }
            handled = true;
        }

        if (handled) {
            flushVtermOutput();
            ev->accept();
        } else {
            QWidget::keyPressEvent(ev);
        }
    }

    // ── Resize ─────────────────────────────────────────────────────────────

    void resizeEvent(QResizeEvent* ev) override {
        QWidget::resizeEvent(ev);
        updateTermSize();
    }

    void focusInEvent(QFocusEvent* ev) override {
        QWidget::focusInEvent(ev);
        update();
    }

    void focusOutEvent(QFocusEvent* ev) override {
        QWidget::focusOutEvent(ev);
        update();
    }

private:
    void flushVtermOutput() {
        char buf[4096];
        size_t len;
        while ((len = vterm_output_read(m_vt, buf, sizeof(buf))) > 0) {
            if (m_master_fd >= 0) {
                ssize_t written = 0;
                while (written < (ssize_t)len) {
                    ssize_t n = ::write(m_master_fd, buf + written, len - written);
                    if (n < 0) {
                        if (errno == EAGAIN || errno == EINTR) continue;
                        break;
                    }
                    written += n;
                }
            }
        }
    }

    void updateTermSize() {
        int new_cols = std::max(2, width()  / m_cell_w);
        int new_rows = std::max(1, height() / m_cell_h);

        if (new_cols != m_cols || new_rows != m_rows) {
            m_rows = new_rows;
            m_cols = new_cols;

            if (m_vt) vterm_set_size(m_vt, m_rows, m_cols);

            if (m_master_fd >= 0) {
                struct winsize ws;
                ws.ws_row    = m_rows;
                ws.ws_col    = m_cols;
                ws.ws_xpixel = width();
                ws.ws_ypixel = height();
                ioctl(m_master_fd, TIOCSWINSZ, &ws);
            }

            update();
        }
    }

    void pollPty() {
        if (m_master_fd < 0) return;

        char buf[8192];
        ssize_t n = 0;
        bool got_data = false;
        // Cap reads per poll to ~64KB so high-output commands (find / -ls, etc.)
        // don't monopolise the Qt event loop and block M-x / other key events.
        static const size_t MAX_BYTES_PER_POLL = 65536;
        size_t total = 0;

        while (total < MAX_BYTES_PER_POLL &&
               (n = ::read(m_master_fd, buf, sizeof(buf))) > 0) {
            vterm_input_write(m_vt, buf, (size_t)n);
            total += (size_t)n;
            got_data = true;
        }

        if (n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR)) {
            checkChildExit();
        }

        if (got_data) {
            vterm_screen_flush_damage(m_screen);
        }
    }

    void checkChildExit() {
        if (m_child_pid > 0) {
            int status;
            pid_t result = waitpid(m_child_pid, &status, WNOHANG);
            if (result == m_child_pid || result < 0) {
                m_running = false;
                m_timer->stop();
                ::close(m_master_fd);
                m_master_fd  = -1;
                m_child_pid  = -1;
                update();
            }
        }
    }
};

// ── C FFI for QTerminalWidget ──────────────────────────────────────────────

typedef void* qt_terminal_t;

extern "C" qt_terminal_t qt_terminal_create(qt_widget_t parent) {
    QT_RETURN(QTerminalWidget*,
        new QTerminalWidget(parent ? static_cast<QWidget*>(parent) : nullptr)
    );
}

extern "C" void qt_terminal_spawn(qt_terminal_t term, const char* cmd) {
    QT_NULL_CHECK_VOID(term);
    std::string cmd_str(cmd ? cmd : "");
    QT_VOID(
        static_cast<QTerminalWidget*>(term)->spawnShell(cmd_str.c_str())
    );
}

extern "C" void qt_terminal_send_input(qt_terminal_t term, const char* data, int len) {
    QT_NULL_CHECK_VOID(term);
    // Copy data before crossing thread boundary
    std::string data_copy(data, len);
    QT_VOID(
        static_cast<QTerminalWidget*>(term)->sendInput(data_copy.c_str(), data_copy.size())
    );
}

// Send a synthetic key event to the terminal widget's keyPressEvent.
// Called from the Scheme key handler to forward non-command keys.
extern "C" void qt_terminal_send_key_event(qt_terminal_t term,
                                            int key, int modifiers,
                                            const char* text) {
    QT_NULL_CHECK_VOID(term);
    std::string text_str(text ? text : "");
    QT_VOID(
        auto* w = static_cast<QTerminalWidget*>(term);
        w->handleKeyEvent(key, modifiers, QString::fromStdString(text_str))
    );
}

extern "C" void qt_terminal_interrupt(qt_terminal_t term) {
    QT_NULL_CHECK_VOID(term);
    QT_VOID(
        static_cast<QTerminalWidget*>(term)->interruptChild()
    );
}

extern "C" int qt_terminal_is_running(qt_terminal_t term) {
    QT_NULL_CHECK_RET(term, 0);
    QT_RETURN(int,
        static_cast<QTerminalWidget*>(term)->isRunning() ? 1 : 0
    );
}

// QTerminalWidget IS a QWidget — return it as-is for QStackedWidget::addWidget
extern "C" qt_widget_t qt_terminal_widget(qt_terminal_t term) {
    return static_cast<qt_widget_t>(term);
}

extern "C" void qt_terminal_set_font(qt_terminal_t term, const char* family, int size) {
    QT_NULL_CHECK_VOID(term);
    std::string fam(family ? family : "DejaVu Sans Mono");
    QT_VOID(
        static_cast<QTerminalWidget*>(term)->setTermFont(fam.c_str(), size)
    );
}

extern "C" void qt_terminal_set_colors(qt_terminal_t term, int fg_rgb, int bg_rgb) {
    QT_NULL_CHECK_VOID(term);
    QT_VOID(
        auto* w = static_cast<QTerminalWidget*>(term);
        w->m_default_fg = QColor((fg_rgb >> 16) & 0xFF, (fg_rgb >> 8) & 0xFF, fg_rgb & 0xFF);
        w->m_default_bg = QColor((bg_rgb >> 16) & 0xFF, (bg_rgb >> 8) & 0xFF, bg_rgb & 0xFF);
        w->update()
    );
}

extern "C" void qt_terminal_focus(qt_terminal_t term) {
    QT_NULL_CHECK_VOID(term);
    QT_VOID(
        static_cast<QTerminalWidget*>(term)->setFocus()
    );
}

extern "C" void qt_terminal_destroy(qt_terminal_t term) {
    QT_NULL_CHECK_VOID(term);
    // 1. Detach from parent (QStackedWidget) so delete-other-windows cannot
    //    double-free the widget when it later destroys the container.
    // 2. Schedule deletion via the event loop (deleteLater) to avoid
    //    "shared QObject deleted directly" crash from pending Qt events.
    //    The destructor calls cleanupPty() which uses WNOHANG — no blocking.
    QT_VOID(
        auto* tw = static_cast<QTerminalWidget*>(term);
        if (QWidget* p = tw->parentWidget()) {
            if (auto* stacked = qobject_cast<QStackedWidget*>(p))
                stacked->removeWidget(tw);
            tw->setParent(nullptr);
        }
        tw->deleteLater()
    );
}
