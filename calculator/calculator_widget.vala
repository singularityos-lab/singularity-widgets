using Gtk;
using GLib;
using Singularity;

namespace SingularityCalculatorWidget {

    public class CalculatorProvider : Object, OverviewWidgetProvider {
        public string id           { get { return "calc.basic"; } }
        public string provider_id  { get { return "dev.sinty.calculator"; } }
        public string display_name { get { return "Calculator"; } }
        public string icon_name    { get { return "accessories-calculator-symbolic"; } }
        public WidgetSize[] supported_sizes {
            get {
                if (_sizes == null) {
                    _sizes = new WidgetSize[5];
                    _sizes[0] = WidgetSize(1, 1);
                    _sizes[1] = WidgetSize(1, 2);
                    _sizes[2] = WidgetSize(2, 2);
                    _sizes[3] = WidgetSize(2, 3);
                    _sizes[4] = WidgetSize(3, 3);
                }
                return _sizes;
            }
        }
        private WidgetSize[] _sizes;
        public Gtk.Widget create_instance(string instance_id, WidgetSize size, Variant? config) {
            return new CalculatorInstance(size);
        }
    }

    /**
     * Inline expression-evaluator calculator. Recursive-descent parser
     * supports + − × ÷ % parentheses and decimals; that's enough for
     * a widget - the full app handles power users.
     */
    public class CalculatorInstance : Gtk.Box {
        private Gtk.Label display_lbl;
        private string expr = "";
        private bool overwrite_on_digit = false;

        public CalculatorInstance(WidgetSize size) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            add_css_class("overview-calculator");
            margin_start = 10; margin_end = 10;
            margin_top = 10; margin_bottom = 10;

            // Make the whole widget fill its cell.
            hexpand = true; vexpand = true;

            display_lbl = new Gtk.Label("0");
            display_lbl.add_css_class("overview-calc-display");
            display_lbl.add_css_class("title-1");
            display_lbl.halign = Align.END;
            display_lbl.xalign = 1.0f;
            display_lbl.hexpand = true;
            display_lbl.vexpand = true;
            display_lbl.valign = Align.CENTER;
            display_lbl.ellipsize = Pango.EllipsizeMode.START;
            display_lbl.max_width_chars = 12;
            base.append(display_lbl);

            var grid = new Gtk.Grid();
            grid.column_spacing = 4;
            grid.row_spacing = 4;
            grid.row_homogeneous = true;
            grid.column_homogeneous = true;
            grid.hexpand = true;
            grid.vexpand = true;
            base.append(grid);

            // Layout: 4 columns × 5 rows.
            //  C   ⌫   %   ÷
            //  7   8   9   ×
            //  4   5   6   −
            //  1   2   3   +
            //  0   .   ( )  =
            add_btn(grid, "C", 0, 0, "func", () => { expr = ""; render(); });
            add_btn(grid, "⌫", 1, 0, "func", () => {
                if (expr.length > 0) expr = expr.substring(0, expr.length - 1);
                render();
            });
            add_btn(grid, "%", 2, 0, "func", () => append("%"));
            add_btn(grid, "÷", 3, 0, "op",   () => append("/"));

            add_btn(grid, "7", 0, 1, "num",  () => append("7"));
            add_btn(grid, "8", 1, 1, "num",  () => append("8"));
            add_btn(grid, "9", 2, 1, "num",  () => append("9"));
            add_btn(grid, "×", 3, 1, "op",   () => append("*"));

            add_btn(grid, "4", 0, 2, "num",  () => append("4"));
            add_btn(grid, "5", 1, 2, "num",  () => append("5"));
            add_btn(grid, "6", 2, 2, "num",  () => append("6"));
            add_btn(grid, "−", 3, 2, "op",   () => append("-"));

            add_btn(grid, "1", 0, 3, "num",  () => append("1"));
            add_btn(grid, "2", 1, 3, "num",  () => append("2"));
            add_btn(grid, "3", 2, 3, "num",  () => append("3"));
            add_btn(grid, "+", 3, 3, "op",   () => append("+"));

            add_btn(grid, "0", 0, 4, "num",  () => append("0"));
            add_btn(grid, ".", 1, 4, "num",  () => append("."));
            add_btn(grid, "( )", 2, 4, "func", () => append_paren());
            add_btn(grid, "=", 3, 4, "accent", () => compute());

            render();
        }

        private void add_btn(Gtk.Grid g, string label, int col, int row,
                              string css_kind, owned VoidFunc cb) {
            var b = new Gtk.Button.with_label(label);
            b.add_css_class("overview-calc-btn");
            b.add_css_class("overview-calc-" + css_kind);
            b.clicked.connect(() => cb());
            g.attach(b, col, row, 1, 1);
        }

        private void append(string s) {
            if (overwrite_on_digit) { expr = ""; overwrite_on_digit = false; }
            expr += s;
            render();
        }

        private void append_paren() {
            // Smart parens: add `(` if count(`(`) == count(`)`), else `)`
            int op = 0, cl = 0;
            for (int i = 0; i < expr.length; i++) {
                if (expr.get_char(i) == '(') op++;
                else if (expr.get_char(i) == ')') cl++;
            }
            append(op == cl ? "(" : ")");
        }

        private void render() {
            display_lbl.label = (expr == "") ? "0" : pretty(expr);
        }

        private string pretty(string s) {
            return s.replace("*", "×").replace("/", "÷").replace("-", "−");
        }

        private void compute() {
            if (expr == "") return;
            try {
                double r = new Eval(expr).parse();
                string s = format_result(r);
                expr = s; overwrite_on_digit = true;
                display_lbl.label = s;
            } catch (Error e) {
                display_lbl.label = "Error";
                overwrite_on_digit = true;
            }
        }

        private string format_result(double r) {
            if (r == Math.floor(r) && r.abs() < 1e15)
                return ((int64) r).to_string();
            return "%.10g".printf(r);
        }
    }

    public delegate void VoidFunc();

    /**
     * Tiny recursive-descent parser for + − × ÷ % parentheses + decimals.
     * No identifiers, no functions - keep it small and predictable.
     */
    public class Eval : Object {
        private string src;
        private int pos;

        public Eval(string s) { src = s; pos = 0; }

        public double parse() throws Error {
            double v = parse_expr();
            skip_ws();
            if (pos < src.length)
                throw new IOError.INVALID_DATA("trailing input");
            return v;
        }

        // expr := term (('+' | '-') term)*
        private double parse_expr() throws Error {
            double v = parse_term();
            while (true) {
                skip_ws();
                if (pos >= src.length) break;
                unichar c = src.get_char(pos);
                if (c == '+') { pos++; v += parse_term(); }
                else if (c == '-') { pos++; v -= parse_term(); }
                else break;
            }
            return v;
        }

        // term := factor (('*' | '/' | '%') factor)*
        private double parse_term() throws Error {
            double v = parse_factor();
            while (true) {
                skip_ws();
                if (pos >= src.length) break;
                unichar c = src.get_char(pos);
                if (c == '*') { pos++; v *= parse_factor(); }
                else if (c == '/') {
                    pos++;
                    double d = parse_factor();
                    if (d == 0) throw new IOError.INVALID_DATA("div0");
                    v /= d;
                } else if (c == '%') {
                    pos++;
                    // "x % y" = remainder; "x %" (postfix) = x / 100 - pick by context
                    if (pos >= src.length || !is_factor_start(src.get_char(pos))) {
                        v = v / 100.0;
                    } else {
                        double d = parse_factor();
                        v = v - Math.floor(v / d) * d;
                    }
                } else break;
            }
            return v;
        }

        private bool is_factor_start(unichar c) {
            return c == '(' || c == '-' || c == '+' || c.isdigit() || c == '.';
        }

        // factor := number | '(' expr ')' | '-' factor | '+' factor
        private double parse_factor() throws Error {
            skip_ws();
            if (pos >= src.length) throw new IOError.INVALID_DATA("unexpected end");
            unichar c = src.get_char(pos);
            if (c == '(') {
                pos++;
                double v = parse_expr();
                skip_ws();
                if (pos < src.length && src.get_char(pos) == ')') pos++;
                return v;
            }
            if (c == '-') { pos++; return -parse_factor(); }
            if (c == '+') { pos++; return  parse_factor(); }
            if (c.isdigit() || c == '.') {
                int start = pos;
                while (pos < src.length &&
                       (src.get_char(pos).isdigit() || src.get_char(pos) == '.'))
                    pos++;
                return double.parse(src.substring(start, pos - start));
            }
            throw new IOError.INVALID_DATA("unexpected '%s'".printf(c.to_string()));
        }

        private void skip_ws() {
            while (pos < src.length && src.get_char(pos).isspace()) pos++;
        }
    }

    [CCode (cname = "singularity_calculator_widget_new")]
    public static Object singularity_calculator_widget_new() {
        return new CalculatorProvider();
    }
}
