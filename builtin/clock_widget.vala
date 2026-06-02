using Gtk;
using GLib;
using Singularity;

namespace SingularityBuiltinWidgets {

    /**
     * Large digital clock + date. Two sizes:
     *   2×1 → time on left, date on right
     *   2×2 → big time, date below, week-of-year subtle line
     */
    public class ClockProvider : Object, OverviewWidgetProvider {
        public string id           { get { return "builtin.clock"; } }
        public string provider_id  { get { return "dev.sinty.builtin"; } }
        public string display_name { get { return "Clock"; } }
        public string icon_name    { get { return "preferences-system-time-symbolic"; } }
        public WidgetSize[] supported_sizes {
            get {
                if (_sizes == null) {
                    _sizes = new WidgetSize[4];
                    _sizes[0] = WidgetSize(1, 1);
                    _sizes[1] = WidgetSize(1, 2);
                    _sizes[2] = WidgetSize(2, 1);
                    _sizes[3] = WidgetSize(2, 2);
                }
                return _sizes;
            }
        }
        private WidgetSize[] _sizes;
        public Gtk.Widget create_instance(string instance_id, WidgetSize size, Variant? config) {
            return new ClockInstance(size);
        }
    }

    public class ClockInstance : Gtk.Box {
        private Gtk.Label time_lbl;
        private Gtk.Label date_lbl;
        private uint tick_id = 0;

        public ClockInstance(WidgetSize size) {
            Object(orientation: (size.h >= 2) ? Orientation.VERTICAL : Orientation.HORIZONTAL,
                   spacing: 6);
            add_css_class("overview-clock");
            // The widget needs to fill its cell (so the veil background
            // covers the whole tile); the inner labels get centred via
            // their own halign/valign below.
            halign = Align.FILL;
            valign = Align.FILL;
            hexpand = true;
            vexpand = true;

            // Inner content is centred inside the filled background.
            var inner = new Gtk.Box(Orientation.VERTICAL, 4);
            inner.halign = Align.CENTER;
            inner.valign = Align.CENTER;
            inner.hexpand = true; inner.vexpand = true;
            inner.margin_start = 16; inner.margin_end = 16;
            inner.margin_top  = 12; inner.margin_bottom = 12;

            time_lbl = new Gtk.Label("");
            time_lbl.add_css_class("title-1");
            time_lbl.add_css_class("overview-clock-time");
            time_lbl.halign = Align.CENTER;
            time_lbl.hexpand = true;
            time_lbl.use_markup = true;
            inner.append(time_lbl);

            date_lbl = new Gtk.Label("");
            date_lbl.add_css_class("dim-label");
            date_lbl.halign = Align.CENTER;
            date_lbl.hexpand = true;
            inner.append(date_lbl);

            base.append(inner);

            tick();
            // Align to the next minute boundary for low-jitter updates.
            uint delay_ms = 60000 - (uint)((GLib.get_real_time() / 1000) % 60000);
            GLib.Timeout.add(int.max(500, (int)delay_ms), () => {
                tick();
                tick_id = GLib.Timeout.add(60000, () => { tick(); return GLib.Source.CONTINUE; });
                return GLib.Source.REMOVE;
            });
            destroy.connect(() => {
                if (tick_id != 0) { GLib.Source.remove(tick_id); tick_id = 0; }
            });
        }

        private void tick() {
            var now = new DateTime.now_local();
            time_lbl.set_markup("<span size='xx-large' weight='600'>" +
                                GLib.Markup.escape_text(now.format("%H:%M")) + "</span>");
            date_lbl.label = now.format("%A, %e %B");
        }
    }

    /* SystemStats was moved to the monitor app - see
       apps/singularity-monitor/widget/system_stats_widget.vala. */
#if NEVER_DEFINED
    public class SystemStatsProvider : Object, OverviewWidgetProvider {
        public string id           { get { return "builtin.system-stats"; } }
        public string provider_id  { get { return "dev.sinty.builtin"; } }
        public string display_name { get { return "System Stats"; } }
        public string icon_name    { get { return "utilities-system-monitor-symbolic"; } }
        public WidgetSize[] supported_sizes {
            get {
                if (_sizes == null) {
                    _sizes = new WidgetSize[2];
                    _sizes[0] = WidgetSize(2, 1);
                    _sizes[1] = WidgetSize(2, 2);
                }
                return _sizes;
            }
        }
        private WidgetSize[] _sizes;
        public Gtk.Widget create_instance(string instance_id, WidgetSize size, Variant? config) {
            return new SystemStatsInstance(size);
        }
    }

    public class SystemStatsInstance : Gtk.Box {
        private Gtk.LevelBar cpu_bar;
        private Gtk.LevelBar ram_bar;
        private Gtk.Label cpu_lbl;
        private Gtk.Label ram_lbl;
        private Gtk.Label bat_lbl;
        private Gtk.LevelBar bat_bar;
        private uint poll_id = 0;
        private uint64 last_total = 0;
        private uint64 last_idle = 0;
        private string? bat_dir = null;

        public SystemStatsInstance(WidgetSize size) {
            Object(orientation: Orientation.VERTICAL, spacing: 8);
            add_css_class("overview-sysstats");
            margin_start = 16; margin_end = 16;
            margin_top = 12; margin_bottom = 12;
            valign = Align.CENTER;

            cpu_bar = new Gtk.LevelBar.for_interval(0, 100);
            ram_bar = new Gtk.LevelBar.for_interval(0, 100);
            cpu_lbl = new Gtk.Label("CPU 0%");
            ram_lbl = new Gtk.Label("RAM 0%");
            cpu_lbl.add_css_class("caption");
            ram_lbl.add_css_class("caption");
            cpu_lbl.halign = Align.START; cpu_lbl.hexpand = true;
            ram_lbl.halign = Align.START; ram_lbl.hexpand = true;

            append(row(cpu_lbl, cpu_bar));
            append(row(ram_lbl, ram_bar));

            // Battery - only added if a /sys/class/power_supply/BAT* exists.
            bat_dir = find_battery();
            if (bat_dir != null) {
                bat_bar = new Gtk.LevelBar.for_interval(0, 100);
                bat_lbl = new Gtk.Label("BAT 0%");
                bat_lbl.add_css_class("caption");
                bat_lbl.halign = Align.START; bat_lbl.hexpand = true;
                append(row(bat_lbl, bat_bar));
            }

            tick();
            poll_id = GLib.Timeout.add(2000, () => { tick(); return GLib.Source.CONTINUE; });
            destroy.connect(() => {
                if (poll_id != 0) { GLib.Source.remove(poll_id); poll_id = 0; }
            });
        }

        private Gtk.Widget row(Gtk.Widget label, Gtk.Widget bar) {
            var b = new Gtk.Box(Orientation.VERTICAL, 2);
            b.append(label);
            b.append(bar);
            return b;
        }

        private void tick() {
            // CPU: parse /proc/stat first line "cpu  u n s i ..."
            try {
                string contents;
                if (FileUtils.get_contents("/proc/stat", out contents)) {
                    var lines = contents.split("\n");
                    if (lines.length > 0 && lines[0].has_prefix("cpu ")) {
                        var parts = lines[0].split(" ");
                        uint64 total = 0, idle = 0;
                        int idx = 0;
                        foreach (var p in parts) {
                            if (p == "" || p == "cpu") continue;
                            uint64 v = uint64.parse(p);
                            if (idx == 3) idle = v; // 0=user 1=nice 2=system 3=idle
                            total += v;
                            idx++;
                        }
                        if (last_total > 0) {
                            uint64 dt = total - last_total;
                            uint64 di = idle  - last_idle;
                            double pct = dt > 0 ? (1.0 - (double)di / (double)dt) * 100.0 : 0.0;
                            cpu_bar.value = pct;
                            cpu_lbl.label = "CPU %.0f%%".printf(pct);
                        }
                        last_total = total; last_idle = idle;
                    }
                }
            } catch (Error e) {}

            // RAM: /proc/meminfo MemTotal/MemAvailable
            try {
                string contents;
                if (FileUtils.get_contents("/proc/meminfo", out contents)) {
                    uint64 total = 0, avail = 0;
                    foreach (var line in contents.split("\n")) {
                        if (line.has_prefix("MemTotal:"))
                            total = parse_meminfo(line);
                        else if (line.has_prefix("MemAvailable:"))
                            avail = parse_meminfo(line);
                    }
                    if (total > 0) {
                        double pct = (1.0 - (double)avail / (double)total) * 100.0;
                        ram_bar.value = pct;
                        ram_lbl.label = "RAM %.0f%%".printf(pct);
                    }
                }
            } catch (Error e) {}

            if (bat_dir != null) tick_battery();
        }

        private uint64 parse_meminfo(string line) {
            // "MemTotal:       16356980 kB"
            var parts = line.split_set(" \t");
            foreach (var p in parts) {
                if (p == "" || p.has_suffix(":") || p == "kB") continue;
                return uint64.parse(p);
            }
            return 0;
        }

        private string? find_battery() {
            try {
                var d = File.new_for_path("/sys/class/power_supply");
                if (!d.query_exists()) return null;
                var en = d.enumerate_children("standard::name", FileQueryInfoFlags.NONE);
                FileInfo? info;
                while ((info = en.next_file()) != null) {
                    string n = info.get_name();
                    if (n.has_prefix("BAT"))
                        return "/sys/class/power_supply/" + n;
                }
            } catch (Error e) {}
            return null;
        }

        private void tick_battery() {
            try {
                string capacity;
                if (FileUtils.get_contents(bat_dir + "/capacity", out capacity)) {
                    double v = double.parse(capacity.strip());
                    bat_bar.value = v;
                    string status = "";
                    string s;
                    if (FileUtils.get_contents(bat_dir + "/status", out s)) status = s.strip();
                    string marker = (status == "Charging") ? "⚡" : "";
                    bat_lbl.label = "BAT %.0f%% %s".printf(v, marker);
                }
            } catch (Error e) {}
        }
    }
#endif

    [CCode (cname = "singularity_widget_clock_new")]
    public static Object singularity_widget_clock_new() {
        return new ClockProvider();
    }
}
