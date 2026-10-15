#!/usr/bin/wish
# DeepOS desktop. Native Tk. Shelf on the left, open stage, live clock.
package require Tk

set ::BG     #0c0b0a
set ::SHELF  #141210
set ::MICA   #1a1714
set ::CARD   #241f1b
set ::LINE   #3a342c
set ::ACCENT #e4c4a0
set ::WHITE  #f6f1ea
set ::GRAY   #a3988c
set ::DIM    #6e675f
set ::HOVER  #2a241e
set ::INK    #1c1612
set ::TERM   #100e0c
set ::DANGER #e81123
set ::CYAN2  $::ACCENT
set ::BAR    #1c1c1c
set ::BARH   68
set ::ICON   34
set ::RAIL   0

font create ui      -family "DejaVu Sans" -size 12
font create title   -family "DejaVu Sans" -size 16
font create small   -family "DejaVu Sans" -size 10
font create tiny    -family "DejaVu Sans" -size 8
font create task    -family "DejaVu Sans" -size 10
font create taskb   -family "DejaVu Sans" -size 13
font create uib     -family "DejaVu Sans" -size 14 -weight bold
font create mono    -family "DejaVu Sans Mono" -size 12

option add *background $::BG
option add *foreground $::WHITE
option add *relief flat
option add *borderWidth 0
option add *highlightThickness 0
option add *activeBackground $::HOVER
option add *activeForeground $::WHITE

proc sh {cmd} {
    if {[catch {exec /bin/sh -c $cmd} out]} { return $out }
    return $out
}
proc readFile {path {limit 4000}} {
    if {![file exists $path]} { return "" }
    set fh [open $path r]
    set data [read $fh $limit]
    close $fh
    return $data
}

set ::host deepos
set hn [string trim [readFile /etc/hostname 80]]
if {$hn ne ""} { set ::host $hn }
set ::user ""
set ::accountId ""
set ::accountAvatar 0
set ::cwd /root
set ::wins {}
set ::active ""
set ::netCache "нет сети"
set ::pins {term files browse firefox chrome settings about gstore}
set ::shown {}
array set ::pinicon {term term files files browse browse settings settings about about pc pc trash trash calendar calendar pkgs apps monitor about log log shot doc updates up power power firefox firefox chrome chrome chat chat gstore gstore}
array set ::pintitle [list term Терминал files Файлы browse "Sun Browser" settings Настройки about Система pc "Мой ПК" trash Корзина calendar Календарь pkgs "Программы для администратора" monitor "Диспетчер задач" log "Системный журнал" shot "Снимок экрана" updates Обновления power Питание firefox Firefox chrome Chrome chat DeepChat gstore G-Store]

wm withdraw .
toplevel .desk
wm overrideredirect .desk 1
wm title .desk DeepOS
set ::SW [winfo screenwidth .]
set ::SH [winfo screenheight .]
wm geometry .desk ${::SW}x${::SH}+0+0
.desk configure -bg $::BG

canvas .desk.bg -bg $::BG -highlightthickness 0 -cursor left_ptr
place .desk.bg -x 0 -y 0 -relx 0 -rely 0 -relwidth 0 -relheight 0 \
    -width $::SW -height $::SH -anchor nw

proc paintWallpaper {} {
    set c .desk.bg
    $c delete all
    set w [winfo width $c]
    set h [winfo height $c]
    if {$w < 100} { set w $::SW }
    if {$h < 100} { set h $::SH }
    set wall sand
    if {[info exists ::set_wall] && $::set_wall ne ""} { set wall $::set_wall }
    if {$wall eq "image" && [info exists ::wallimg]} {
        $c create rectangle 0 0 $w $h -fill #111111 -outline {}
        $c create image [expr {$w / 2}] [expr {$h / 2}] -anchor center -image ::wallimg
        return
    }
    array set pal {
        sand {#111111 #171717}
        night {#101820 #1c3048}
        mist {#141418 #2a2a32}
        forest {#101612 #1e3326}
        ink {#0c0c0c #1a1a1a}
    }
    if {![info exists pal($wall)]} { set wall sand }
    lassign $pal($wall) bg glow
    if {[info exists ::set_theme] && $::set_theme eq "contrast"} {
        set bg #000000
        set glow #2a2a00
    }
    $c create rectangle 0 0 $w $h -fill $bg -outline {}
    $c create oval [expr {$w * 0.05}] [expr {-$h * 0.35}] [expr {$w * 0.92}] [expr {$h * 0.72}] \
        -fill $glow -outline {}
}
paintWallpaper
bind .desk.bg <Configure> paintWallpaper

# Bottom panel, Windows 11 layout. Buttons open real windows.
frame .desk.bar -bg $::BAR -height $::BARH
place .desk.bar -x 0 -y [expr {$::SH - $::BARH}] -relx 0 -rely 0 -relwidth 0 -relheight 0 \
    -width $::SW -height $::BARH -anchor nw
pack propagate .desk.bar 0
frame .desk.bar.line -bg #2a2a2a -height 1
place .desk.bar.line -x 0 -y 0 -relx 0 -rely 0 -relwidth 1 -relheight 0 -height 1 -anchor nw

frame .desk.bar.peek -bg $::BAR -width 6 -cursor hand2
pack .desk.bar.peek -side right -fill y
pack propagate .desk.bar.peek 0
bind .desk.bar.peek <Enter> {.desk.bar.peek configure -bg #f2f2f2}
bind .desk.bar.peek <Leave> {.desk.bar.peek configure -bg $::BAR}
bind .desk.bar.peek <Button-1> showDesktop

frame .desk.bar.clock -bg $::BAR -cursor hand2
pack .desk.bar.clock -side right -padx {6 10}
label .desk.bar.clock.t -text "00:00" -bg $::BAR -fg #f3f3f3 -font taskb
label .desk.bar.clock.d -text "" -bg $::BAR -fg #d0d0d0 -font tiny
pack .desk.bar.clock.t .desk.bar.clock.d

frame .desk.bar.tray -bg $::BAR
pack .desk.bar.tray -side right -padx 2

proc trayIcon {name kind cmd} {
    canvas .desk.bar.tray.$name -width 20 -height 20 -bg $::BAR -highlightthickness 0 -cursor hand2
    pack .desk.bar.tray.$name -side left -padx 7 -pady [expr {($::BARH - 20) / 2}]
    drawIcon .desk.bar.tray.$name $kind
    bind .desk.bar.tray.$name <Button-1> $cmd
    bind .desk.bar.tray.$name <Enter> [list .desk.bar.tray.$name configure -bg #2d2d2d]
    bind .desk.bar.tray.$name <Leave> [list .desk.bar.tray.$name configure -bg $::BAR]
}

frame .desk.bar.mid -bg $::BAR
frame .desk.bar.mid.pins -bg $::BAR
pack .desk.bar.mid.pins -side left -anchor w -padx {4 0}
pack .desk.bar.mid -side left -fill both -expand 1

proc drawIcon {c kind} {
    $c delete all
    set s [winfo reqwidth $c]
    if {$s < 12} { set s 22 }
    set u [expr {$s / 22.0}]
    set fg #f3f3f3
    proc _x {u v} {expr {int($v * $u)}}
    switch $kind {
        start {
            foreach {a b d e} {3 3 10 10  12 3 19 10  3 12 10 19  12 12 19 19} {
                $c create rectangle [_x $u $a] [_x $u $b] [_x $u $d] [_x $u $e] -fill $fg -outline {}
            }
        }
        search {
            $c create oval [_x $u 3] [_x $u 3] [_x $u 13] [_x $u 13] -outline $fg -width [expr {$u < 1.1 ? 1 : 2}]
            $c create line [_x $u 12] [_x $u 12] [_x $u 19] [_x $u 19] -fill $fg -width [expr {$u < 1.1 ? 1 : 2}]
        }
        tasks {
            $c create rectangle [_x $u 2] [_x $u 4] [_x $u 13] [_x $u 13] -outline $fg -width 1
            $c create rectangle [_x $u 7] [_x $u 8] [_x $u 19] [_x $u 18] -outline #d0d0d0 -width 1
        }
        term {
            set cx [expr {$s / 2.0}]
            set cy [expr {$s / 2.0}]
            $c create rectangle [expr {int($s*0.12)}] [expr {int($s*0.18)}] [expr {int($s*0.88)}] [expr {int($s*0.82)}] -fill #12352a -outline {}
            set arm [expr {$s * 0.16}]
            $c create line [expr {$cx-$arm}] [expr {$cy-$arm}] [expr {$cx+$arm*0.4}] $cy -fill #3ddc84 -width 2 -capstyle round
            $c create line [expr {$cx+$arm*0.4}] $cy [expr {$cx-$arm}] [expr {$cy+$arm}] -fill #3ddc84 -width 2 -capstyle round
        }
        files {
            $c create polygon \
                [_x $u 2] [_x $u 8] [_x $u 8] [_x $u 8] [_x $u 10] [_x $u 5] \
                [_x $u 20] [_x $u 5] [_x $u 20] [_x $u 18] [_x $u 2] [_x $u 18] \
                -fill #ffb900 -outline {}
        }
        browse {
            set cx [expr {$s / 2.0}]
            set cy [expr {$s / 2.0}]
            set i 0
            while {$i < 8} {
                set a [expr {$i * 0.785398}]
                $c create line \
                    [expr {$cx + cos($a) * $s * 0.28}] [expr {$cy + sin($a) * $s * 0.28}] \
                    [expr {$cx + cos($a) * $s * 0.44}] [expr {$cy + sin($a) * $s * 0.44}] \
                    -fill #ffb020 -width [expr {$s >= 28 ? 2 : 1}] -capstyle round
                incr i
            }
            set r [expr {$s * 0.20}]
            $c create oval [expr {$cx - $r}] [expr {$cy - $r}] [expr {$cx + $r}] [expr {$cy + $r}] -fill #ffb020 -outline {}
        }
        settings {
            $c create oval [_x $u 7] [_x $u 7] [_x $u 15] [_x $u 15] -outline $fg -width [expr {$u < 1.1 ? 1 : 2}]
            $c create line [_x $u 11] [_x $u 2] [_x $u 11] [_x $u 5] -fill $fg -width [expr {$u < 1.1 ? 1 : 2}]
            $c create line [_x $u 11] [_x $u 17] [_x $u 11] [_x $u 20] -fill $fg -width [expr {$u < 1.1 ? 1 : 2}]
            $c create line [_x $u 2] [_x $u 11] [_x $u 5] [_x $u 11] -fill $fg -width [expr {$u < 1.1 ? 1 : 2}]
            $c create line [_x $u 17] [_x $u 11] [_x $u 20] [_x $u 11] -fill $fg -width [expr {$u < 1.1 ? 1 : 2}]
        }
        about {
            set cx [expr {$s / 2.0}]
            set cy [expr {$s / 2.0}]
            set r [expr {$s * 0.36}]
            set lw [expr {$s >= 28 ? 2 : 1}]
            $c create oval [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}] -outline #60cdff -width $lw
            set dot [expr {$s * 0.055}]
            if {$dot < 1.2} { set dot 1.2 }
            set dy [expr {$cy - $s * 0.14}]
            $c create oval [expr {$cx-$dot}] [expr {$dy-$dot}] [expr {$cx+$dot}] [expr {$dy+$dot}] -fill #60cdff -outline {}
            set sw [expr {$s * 0.055}]
            if {$sw < 1} { set sw 1 }
            $c create rectangle [expr {$cx-$sw}] [expr {$cy - $s*0.02}] [expr {$cx+$sw}] [expr {$cy + $s*0.2}] -fill #60cdff -outline {}
        }
        doc {
            $c create polygon [_x $u 5] [_x $u 2] [_x $u 14] [_x $u 2] [_x $u 18] [_x $u 6] [_x $u 18] [_x $u 20] [_x $u 5] [_x $u 20] -fill #f3f3f3 -outline {}
            $c create polygon [_x $u 14] [_x $u 2] [_x $u 14] [_x $u 6] [_x $u 18] [_x $u 6] -fill #c8c8c8 -outline {}
        }
        up {
            $c create polygon [_x $u 3] [_x $u 10] [_x $u 8] [_x $u 5] [_x $u 13] [_x $u 10] -fill #d6d6d6 -outline {}
        }
        net {
            $c create arc [_x $u 0] [_x $u 5] [_x $u 16] [_x $u 18] -start 15 -extent 150 -style arc -outline #6a6a6a -width 1 -tags wave
            $c create arc [_x $u 3] [_x $u 8] [_x $u 13] [_x $u 16] -start 15 -extent 150 -style arc -outline #6a6a6a -width 1 -tags wave
            $c create oval [_x $u 7] [_x $u 12] [_x $u 9] [_x $u 14] -fill #6a6a6a -outline {} -tags dot
        }
        vol {
            $c create polygon [_x $u 1] [_x $u 6] [_x $u 4] [_x $u 6] [_x $u 8] [_x $u 3] [_x $u 8] [_x $u 13] [_x $u 4] [_x $u 10] [_x $u 1] [_x $u 10] -fill #e6e6e6 -outline {}
            $c create arc [_x $u 7] [_x $u 4] [_x $u 14] [_x $u 12] -start -50 -extent 100 -style arc -outline #e6e6e6 -width 1
        }
        power {
            $c create arc [_x $u 3] [_x $u 3] [_x $u 13] [_x $u 13] -start 140 -extent 260 -style arc -outline #e6e6e6 -width 2
            $c create line [_x $u 8] [_x $u 2] [_x $u 8] [_x $u 8] -fill #e6e6e6 -width 2
        }
        pc {
            $c create rectangle [_x $u 2] [_x $u 3] [_x $u 20] [_x $u 15] -fill #0078d7 -outline {}
            $c create rectangle [_x $u 4] [_x $u 5] [_x $u 18] [_x $u 13] -fill #d6ecff -outline {}
            $c create rectangle [_x $u 9] [_x $u 15] [_x $u 13] [_x $u 17] -fill #0078d7 -outline {}
            $c create rectangle [_x $u 6] [_x $u 17] [_x $u 16] [_x $u 19] -fill #0078d7 -outline {}
        }
        calendar {
            $c create rectangle [_x $u 3] [_x $u 4] [_x $u 19] [_x $u 19] -fill #f4f4f4 -outline {}
            $c create rectangle [_x $u 3] [_x $u 4] [_x $u 19] [_x $u 8] -fill #e4c4a0 -outline {}
            $c create rectangle [_x $u 6] [_x $u 2] [_x $u 8] [_x $u 6] -fill #f4f4f4 -outline {}
            $c create rectangle [_x $u 14] [_x $u 2] [_x $u 16] [_x $u 6] -fill #f4f4f4 -outline {}
            $c create rectangle [_x $u 6] [_x $u 11] [_x $u 9] [_x $u 14] -fill #1c1c1c -outline {}
            $c create rectangle [_x $u 11] [_x $u 11] [_x $u 16] [_x $u 14] -fill #c8c8c8 -outline {}
        }
        trash {
            $c create rectangle [_x $u 4] [_x $u 6] [_x $u 18] [_x $u 8] -fill #8a8a8a -outline {}
            $c create rectangle [_x $u 8] [_x $u 4] [_x $u 14] [_x $u 6] -fill #8a8a8a -outline {}
            $c create polygon [_x $u 5] [_x $u 8] [_x $u 7] [_x $u 19] [_x $u 15] [_x $u 19] [_x $u 17] [_x $u 8] -fill #d0d0d0 -outline {}
        }
        trashfull {
            $c create rectangle [_x $u 4] [_x $u 6] [_x $u 18] [_x $u 8] -fill #8a8a8a -outline {}
            $c create rectangle [_x $u 8] [_x $u 4] [_x $u 14] [_x $u 6] -fill #8a8a8a -outline {}
            $c create polygon [_x $u 5] [_x $u 8] [_x $u 7] [_x $u 19] [_x $u 15] [_x $u 19] [_x $u 17] [_x $u 8] -fill #d0d0d0 -outline {}
            $c create rectangle [_x $u 9] [_x $u 10] [_x $u 13] [_x $u 16] -fill #ffffff -outline {}
        }
        apps {
            foreach {a b} {3 3  12 3  3 12  12 12} {
                $c create rectangle [_x $u $a] [_x $u $b] [_x $u [expr {$a + 7}]] [_x $u [expr {$b + 7}]] -fill #60cdff -outline {}
            }
        }
        firefox {
            set cx [expr {$s / 2.0}]
            set cy [expr {$s / 2.0}]
            set r [expr {$s * 0.38}]
            $c create oval [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}] -fill #ff7139 -outline {}
            $c create text $cx $cy -text F -fill #ffffff -font taskb
        }
        chrome {
            set cx [expr {$s / 2.0}]
            set cy [expr {$s / 2.0}]
            set r [expr {$s * 0.16}]
            $c create oval [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}] -fill #ffffff -outline {}
            foreach {dx dy col} {0 -0.28 #ea4335  0.26 0.16 #fbbc05  -0.26 0.16 #34a853} {
                set rr [expr {$s * 0.11}]
                set x [expr {$cx + $dx * $s}]
                set y [expr {$cy + $dy * $s}]
                $c create oval [expr {$x-$rr}] [expr {$y-$rr}] [expr {$x+$rr}] [expr {$y+$rr}] -fill $col -outline {}
            }
        }
        exe {
            $c create rectangle [expr {int($s*0.16)}] [expr {int($s*0.12)}] [expr {int($s*0.84)}] [expr {int($s*0.88)}] -fill #1a4f8b -outline {}
            $c create polygon [expr {int($s*0.58)}] [expr {int($s*0.12)}] [expr {int($s*0.84)}] [expr {int($s*0.12)}] [expr {int($s*0.84)}] [expr {int($s*0.38)}] -fill #7eb6ff -outline {}
            $c create text [expr {$s*0.42}] [expr {$s*0.58}] -text E -fill #ffffff -font taskb
        }
        chat {
            $c create oval [_x $u 2] [_x $u 3] [_x $u 14] [_x $u 13] -fill #e4c4a0 -outline {}
            $c create oval [_x $u 8] [_x $u 8] [_x $u 20] [_x $u 18] -fill #ffffff -outline {}
        }
        gstore {
            $c create rectangle [_x $u 4] [_x $u 8] [_x $u 18] [_x $u 18] -fill #e4c4a0 -outline {}
            $c create polygon [_x $u 7] [_x $u 8] [_x $u 9] [_x $u 4] [_x $u 13] [_x $u 4] [_x $u 15] [_x $u 8] -fill #ffffff -outline {}
        }
        log {
            $c create rectangle [_x $u 4] [_x $u 3] [_x $u 18] [_x $u 19] -fill #f6f1ea -outline {}
            $c create rectangle [_x $u 7] [_x $u 7] [_x $u 15] [_x $u 8] -fill #1c1612 -outline {}
            $c create rectangle [_x $u 7] [_x $u 11] [_x $u 15] [_x $u 12] -fill #e4c4a0 -outline {}
            $c create rectangle [_x $u 7] [_x $u 15] [_x $u 13] [_x $u 16] -fill #1c1612 -outline {}
        }
    }
}

trayIcon up up showHidden
trayIcon net net showHidden
trayIcon vol vol {openApp settings}
trayIcon pwr power shutdown

proc shortTitle {s} {
    if {[string length $s] <= 16} { return $s }
    return "[string range $s 0 14]..."
}
proc titleOf {id} {
    if {[info exists ::title($id)] && $::title($id) ne ""} { return $::title($id) }
    if {[info exists ::pintitle($id)]} { return $::pintitle($id) }
    return $id
}
proc kindOf {id} {
    if {[info exists ::pinicon($id)]} { return $::pinicon($id) }
    return doc
}

proc tintBtn {b bg} {
    $b configure -bg $bg
    foreach w [list $b.i $b.clip] {
        if {[winfo exists $w]} { $w configure -bg $bg }
    }
    if {[winfo exists $b.clip.t]} { $b.clip.t configure -bg $bg }
}
proc windowOpen {id} {
    if {$id eq "start" || $id eq "search" || $id eq "tasks"} { return 0 }
    if {[winfo exists .w$id]} { return 1 }
    return 0
}
proc makeBtn {id kind title} {
    set b .desk.bar.mid.pins.b$id
    frame $b -bg $::BAR -height $::BARH -cursor hand2
    pack $b -side left -padx 2
    pack propagate $b 0
    canvas $b.i -width $::ICON -height $::ICON -bg $::BAR -highlightthickness 0
    pack $b.i -side left -padx {14 6}
    drawIcon $b.i $kind
    set ::btnBase($id) [expr {14 + $::ICON + 10}]
    set ::btnTextW($id) 0
    if {$title ne "" && $id ne "start" && $id ne "search" && $id ne "tasks"} {
        set shown [shortTitle $title]
        set ::btnTextW($id) [expr {[font measure task $shown] + 22}]
        frame $b.clip -bg $::BAR -height $::BARH -width 1
        pack $b.clip -side left -fill y
        pack propagate $b.clip 0
        label $b.clip.t -text $shown -bg $::BAR -fg #f5f5f5 -font task -anchor w
    }
    $b configure -width $::btnBase($id)
    frame $b.u -bg $::BAR -height 3 -width 1
    set cx [expr {14 + $::ICON / 2}]
    place $b.u -x $cx -relx 0 -rely 1.0 -anchor s -y -7 -width 1 -height 3
    set widgets [list $b $b.i]
    if {[winfo exists $b.clip]} { lappend widgets $b.clip }
    if {[winfo exists $b.clip.t]} { lappend widgets $b.clip.t }
    foreach w $widgets {
        bind $w <Button-1> [list taskClick $id]
        bind $w <Enter> [list tintBtn $b #2e2e2e]
        bind $w <Leave> [list btnLeave $b]
    }
    if {![info exists ::blend($id)]} {
        set ::blend($id) 0
    }
    applyBlend $b $id $::blend($id)
}
proc applyBlend {b id t} {
    if {![winfo exists $b]} return
    if {$t < 0} { set t 0 }
    if {$t > 1} { set t 1 }
    set clip 0
    if {[info exists ::btnTextW($id)] && $::btnTextW($id) > 0 && [winfo exists $b.clip.t]} {
        if {$t < 0.05} {
            place forget $b.clip.t
            $b.clip configure -width 1
            set clip 0
        } else {
            set clip [expr {int($::btnTextW($id) * $t)}]
            if {$clip < 1} { set clip 1 }
            $b.clip configure -width $clip
            place $b.clip.t -in $b.clip -x 10 -rely 0.5 -anchor w
        }
    }
    set base 52
    if {[info exists ::btnBase($id)]} { set base $::btnBase($id) }
    $b configure -width [expr {$base + $clip}]
    set barw [expr {int(14 * $t)}]
    if {$barw < 1} { set barw 1 }
    set col $::BAR
    if {$t > 0.12} {
        if {$::active eq $id && [winfo exists .w$id] && [winfo ismapped .w$id]} {
            set col #f7f7f7
        } else {
            set col #8d8d8d
        }
    }
    if {[winfo exists $b.u]} {
        $b.u configure -bg $col -width $barw
    }
}
proc btnLeave {b} {
    set px [winfo pointerx .]
    set py [winfo pointery .]
    set x1 [winfo rootx $b]
    set y1 [winfo rooty $b]
    set x2 [expr {$x1 + [winfo width $b]}]
    set y2 [expr {$y1 + [winfo height $b]}]
    if {$px >= $x1 && $px < $x2 && $py >= $y1 && $py < $y2} return
    tintBtn $b $::BAR
}

proc paintPins {} {
    if {[info exists ::pinWait]} { after cancel $::pinWait }
    set ::pinWait [after idle doPaintPins]
}
proc pinIds {} {
    set ids [list start search tasks]
    foreach id $::pins { lappend ids $id }
    foreach id $::wins {
        if {[lsearch -exact $::pins $id] < 0 && [winfo exists .w$id]} { lappend ids $id }
    }
    return $ids
}
proc doPaintPins {} {
    unset -nocomplain ::pinWait
    set parent .desk.bar.mid.pins
    if {![winfo exists $parent]} return
    set ids [pinIds]
    set key [join $ids ,]
    set titles ""
    foreach id $ids { append titles [titleOf $id] | }
    if {![info exists ::pinKey] || $::pinKey ne "$key $titles"} {
        set ::pinKey "$key $titles"
        foreach w [winfo children $parent] { destroy $w }
        foreach id $ids {
            if {$id eq "start"} {
                makeBtn start start ""
            } elseif {$id eq "search"} {
                makeBtn search search ""
            } elseif {$id eq "tasks"} {
                makeBtn tasks tasks ""
            } else {
                makeBtn $id [kindOf $id] [titleOf $id]
            }
        }
    } else {
        foreach id $ids {
            set b $parent.b$id
            if {[winfo exists $b]} { applyBlend $b $id [expr {[info exists ::blend($id)] ? $::blend($id) : 0}] }
        }
    }
    kickAnim
}
proc kickAnim {} {
    if {[info exists ::animRun]} return
    set ::animRun 1
    animStep
}
proc animStep {} {
    if {![winfo exists .desk.bar.mid.pins]} {
        unset -nocomplain ::animRun
        return
    }
    set busy 0
    foreach id [pinIds] {
        set b .desk.bar.mid.pins.b$id
        if {![winfo exists $b]} continue
        set target [windowOpen $id]
        if {![info exists ::blend($id)]} { set ::blend($id) 0.0 }
        set cur $::blend($id)
        set step 0.12
        set mode normal
        if {[info exists ::set_anim]} { set mode $::set_anim }
        if {$mode eq "off"} {
            set cur $target
        } else {
            if {$mode eq "slow"} { set step 0.05 }
            if {$mode eq "fast"} { set step 0.35 }
            if {abs($cur - $target) > 0.02} {
                if {$cur < $target} {
                    set cur [expr {$cur + $step}]
                    if {$cur > $target} { set cur $target }
                } else {
                    set cur [expr {$cur - $step}]
                    if {$cur < $target} { set cur $target }
                }
                set busy 1
            } else {
                set cur $target
            }
        }
        set ::blend($id) $cur
        applyBlend $b $id $cur
    }
    set delay 20
    if {[info exists ::set_anim] && $::set_anim eq "slow"} { set delay 40 }
    if {[info exists ::set_anim] && $::set_anim eq "fast"} { set delay 12 }
    if {$busy} {
        set ::animRun [after $delay animStep]
    } else {
        unset -nocomplain ::animRun
    }
}

proc taskClick {id} {
    soundPlay click
    hideCtx
    if {$id eq "start"} { toggleStart; return }
    if {$id eq "search"} { showStart; focus .desk.menu.q; return }
    if {$id eq "tasks"} { showTasks; return }
    hideStart
    if {[winfo exists .w$id] && [winfo ismapped .w$id] && $::active eq $id} {
        minWin $id
        return
    }
    if {[winfo exists .w$id]} {
        wm deiconify .w$id
        raiseWin $id
        return
    }
    openApp $id
}
proc focusWin {id} {
    hideStart
    hideCtx
    if {![winfo exists .w$id]} { openApp $id; return }
    wm deiconify .w$id
    raiseWin $id
}
proc showDesktop {} {
    hideStart
    hideCtx
    if {[llength $::shown] > 0} {
        foreach id $::shown {
            if {[winfo exists .w$id]} { wm deiconify .w$id }
        }
        set ::shown {}
        paintPins
        return
    }
    set ::shown {}
    foreach id $::wins {
        if {[winfo exists .w$id] && [winfo ismapped .w$id]} {
            lappend ::shown $id
            wm withdraw .w$id
        }
    }
    set ::active ""
    paintPins
}

set ::startPinned {term files browse settings pc trash about}
set ::startCatalog {
    {browse {Sun Browser} internet}
    {firefox Firefox internet}
    {chrome Chrome internet}
    {files Файлы office}
    {settings Настройки system}
    {about Система system}
    {pc {Мой ПК} system}
    {trash Корзина system}
    {calendar Календарь system}
    {gstore G-Store system}
    {pkgs {Программы для администратора} system}
    {monitor {Диспетчер задач} system}
    {log {Системный журнал} system}
    {shot {Снимок экрана} system}
    {updates Обновления system}
    {term Терминал dev}
    {chat DeepChat internet}
}
set ::startCatNames {internet Интернет games Игры office Офис system Система dev Разработка}
foreach {id name} $::startCatNames { set ::startOpen($id) 0 }
set ::recent {}
set ::startIndex {}
set ::hit 0
set ::hitCmd {}
set ::hitIds {}

frame .desk.menu -bg #1c1c1c -highlightthickness 1 -highlightbackground #3a3a3a
pack propagate .desk.menu 0
frame .desk.menu.top -bg #1c1c1c
pack .desk.menu.top -side top -fill x -padx 16 -pady {14 8}
frame .desk.menu.top.bar -bg #2a2a2a -highlightthickness 1 -highlightbackground #3a3a3a -highlightcolor #e4c4a0
pack .desk.menu.top.bar -fill x
canvas .desk.menu.top.bar.ic -width 18 -height 18 -bg #2a2a2a -highlightthickness 0
pack .desk.menu.top.bar.ic -side left -padx {10 4} -pady 8
drawIcon .desk.menu.top.bar.ic search
entry .desk.menu.q -bg #2a2a2a -fg #f4f4f4 -insertbackground #e4c4a0 -font ui \
    -highlightthickness 0 -bd 0 -relief flat
pack .desk.menu.q -in .desk.menu.top.bar -side left -fill x -expand 1 -ipady 8 -padx 4
label .desk.menu.top.bar.ph -text "Поиск..." -bg #2a2a2a -fg #8a8a8a -font ui
place .desk.menu.top.bar.ph -in .desk.menu.top.bar -x 42 -rely 0.5 -anchor w
label .desk.menu.top.bar.esc -text "Esc" -bg #333333 -fg #d0d0d0 -font tiny -padx 8 -pady 3 -cursor hand2
pack .desk.menu.top.bar.esc -side right -padx 8 -pady 6
bind .desk.menu.top.bar.ph <Button-1> { focus .desk.menu.q }
bind .desk.menu.top.bar.esc <Button-1> hideStart
bind .desk.menu.q <KeyRelease> { startType %K }
bind .desk.menu.q <Escape> { hideStart; break }
bind .desk.menu.q <Return> { startActivate; break }
bind .desk.menu.q <Down> { startMove 1; break }
bind .desk.menu.q <Up> { startMove -1; break }
bind .desk.menu.q <Right> { if {[string trim [.desk.menu.q get]] eq ""} { startMove 1; break } }
bind .desk.menu.q <Left> { if {[string trim [.desk.menu.q get]] eq ""} { startMove -1; break } }
bind .desk.menu <Escape> { hideStart; break }

frame .desk.menu.foot -bg #1c1c1c
pack .desk.menu.foot -side bottom -fill x
frame .desk.menu.foot.line -bg #333333 -height 1
pack .desk.menu.foot.line -fill x
frame .desk.menu.foot.row -bg #1c1c1c
pack .desk.menu.foot.row -fill x -padx 8 -pady 8
canvas .desk.menu.foot.row.av -width 32 -height 32 -bg #1c1c1c -highlightthickness 0
pack .desk.menu.foot.row.av -side left -padx {6 0}
.desk.menu.foot.row.av create oval 2 2 30 30 -fill #e4c4a0 -outline {}
.desk.menu.foot.row.av create text 16 16 -text "R" -fill #1a140e -font taskb
label .desk.menu.foot.row.u -text "root" -bg #1c1c1c -fg #f4f4f4 -font ui
pack .desk.menu.foot.row.u -side left -padx 10
label .desk.menu.foot.row.set -text "Настройки" -bg #1c1c1c -fg #f3f3f3 -font task -padx 12 -pady 6 -cursor hand2
pack .desk.menu.foot.row.set -side right -padx 4
label .desk.menu.foot.row.pwr -text "Питание" -bg #1c1c1c -fg #f3f3f3 -font task -padx 12 -pady 6 -cursor hand2
pack .desk.menu.foot.row.pwr -side right -padx 4
bind .desk.menu.foot.row.set <Button-1> { openApp settings }
bind .desk.menu.foot.row.pwr <Button-1> showPower
bind .desk.menu.foot.row.set <Enter> {.desk.menu.foot.row.set configure -bg #2e2e2e}
bind .desk.menu.foot.row.set <Leave> {.desk.menu.foot.row.set configure -bg #1c1c1c}
bind .desk.menu.foot.row.pwr <Enter> {.desk.menu.foot.row.pwr configure -bg #2e2e2e}
bind .desk.menu.foot.row.pwr <Leave> {.desk.menu.foot.row.pwr configure -bg #1c1c1c}

frame .desk.menu.mid -bg #1c1c1c
pack .desk.menu.mid -fill both -expand 1 -padx 8 -pady {0 4}

frame .desk.power -bg #2c2c2c -highlightthickness 1 -highlightbackground #3a3a3a
foreach {name text cmd} {
    off {Завершить работу} doShutdown
    reb {Перезагрузить} doReboot
    slp {Спящий режим} doSleep
    lck {Заблокировать} lockSession
    out {Выйти из сессии} doLogout
} {
    label .desk.power.$name -text $text -bg #2c2c2c -fg #f3f3f3 -font task -anchor w -padx 16 -pady 8 -cursor hand2
    pack .desk.power.$name -fill x
    bind .desk.power.$name <Button-1> $cmd
    bind .desk.power.$name <Enter> [list .desk.power.$name configure -bg #383838]
    bind .desk.power.$name <Leave> [list .desk.power.$name configure -bg #2c2c2c]
}

proc startType {key} {
    if {$key eq "Up" || $key eq "Down" || $key eq "Left" || $key eq "Right"} return
    if {$key eq "Escape" || $key eq "Return"} return
    fillSearch
}
proc startMove {d} {
    set n [llength $::hitCmd]
    if {$n < 1} return
    set ::hit [expr {$::hit + $d}]
    if {$::hit >= $n} { set ::hit 0 }
    if {$::hit < 0} { set ::hit [expr {$n - 1}] }
    startMarkHit
}
proc startActivate {} {
    if {![info exists ::hitCmd] || [llength $::hitCmd] < 1} return
    set i $::hit
    if {$i < 0 || $i >= [llength $::hitCmd]} { set i 0 }
    set cmd [lindex $::hitCmd $i]
    hideStart
    uplevel #0 $cmd
}
proc startPick {i} {
    set ::hit $i
    startActivate
}
proc fuzzyScore {query text} {
    set q [string tolower $query]
    set t [string tolower $text]
    if {$q eq ""} { return 1 }
    set at [string first $q $t]
    if {$at >= 0} { return [expr {200 - $at}] }
    set ti 0
    set score 0
    set last -1
    set ql [string length $q]
    set tl [string length $t]
    for {set i 0} {$i < $ql} {incr i} {
        set ch [string index $q $i]
        set found -1
        for {set j $ti} {$j < $tl} {incr j} {
            if {[string index $t $j] eq $ch} { set found $j; break }
        }
        if {$found < 0} { return 0 }
        if {$last >= 0 && $found == $last + 1} { incr score 4 } else { incr score 1 }
        set last $found
        set ti [expr {$found + 1}]
    }
    return $score
}
proc startBuildIndex {} {
    set ::startIndex {}
    foreach row $::startCatalog {
        lassign $row id title cat
        lappend ::startIndex [list app $title $id ""]
    }
    foreach dir {/root /root/Desktop} {
        foreach f [glob -nocomplain -directory $dir *] {
            set base [file tail $f]
            if {[string match .* $base]} continue
            lappend ::startIndex [list file $base "" $f]
        }
    }
    foreach f [glob -nocomplain /etc/*.conf /usr/share/deepos/*] {
        if {![file isfile $f]} continue
        lappend ::startIndex [list file [file tail $f] "" $f]
    }
    recentRefresh
}
proc recentFile {} { return /root/.deepos/recent }
proc recentLoad {} {
    set ::recent {}
    if {![file exists [recentFile]]} return
    set fh [open [recentFile] r]
    while {[gets $fh line] >= 0} {
        if {![regexp {^([0-9]+)\t([^\t]+)\t(.+)$} $line -> when title cmd]} continue
        lappend ::recent [list $title $cmd $when]
        if {[llength $::recent] >= 6} break
    }
    close $fh
}
proc recentSave {} {
    file mkdir /root/.deepos
    set fh [open [recentFile] w]
    foreach item $::recent {
        set title [lindex $item 0]
        set cmd [lindex $item 1]
        set when [lindex $item 2]
        if {$when eq ""} { set when 0 }
        puts $fh "$when\t$title\t$cmd"
    }
    close $fh
}
proc recentRefresh {} {
    set batch {}
    foreach dir {/root/Desktop /root} {
        foreach f [glob -nocomplain -directory $dir *] {
            set base [file tail $f]
            if {[string match .* $base]} continue
            catch { lappend batch [list [file mtime $f] $base $f] }
        }
    }
    set batch [lsort -integer -index 0 -decreasing $batch]
    foreach item [lrange $batch 0 3] {
        set title [lindex $item 1]
        set found 0
        foreach have $::recent {
            if {[lindex $have 0] eq $title} { set found 1 }
        }
        if {$found} continue
        lappend ::recent [list $title [list openPath [lindex $item 2]] [lindex $item 0]]
    }
    if {[llength $::recent] > 6} { set ::recent [lrange $::recent 0 5] }
}
proc recentWhen {when} {
    if {$when eq "" || ![string is integer -strict $when] || $when < 1} { return "" }
    set ago [expr {[clock seconds] - $when}]
    if {$ago < 60} { return "сейчас" }
    if {$ago < 3600} { return "[expr {$ago / 60}] мин" }
    if {$ago < 86400} { return [clock format $when -format %H:%M] }
    return [clock format $when -format %d.%m]
}
proc noteRecent {title cmd} {
    if {$title eq ""} return
    set now [clock seconds]
    set new [list [list $title $cmd $now]]
    foreach item $::recent {
        if {[lindex $item 0] eq $title} continue
        lappend new $item
        if {[llength $new] >= 6} break
    }
    set ::recent $new
    recentSave
    if {[winfo exists .desk.menu] && [winfo ismapped .desk.menu]} {
        set q ""
        catch { set q [string trim [.desk.menu.q get]] }
        if {$q eq ""} { fillSearch }
    }
}
proc startQuery {q} {
    if {![info exists ::startIndex] || [llength $::startIndex] == 0} { startBuildIndex }
    set hits {}
    set n 0
    foreach item $::startIndex {
        lassign $item kind title id path
        set s [fuzzyScore $q $title]
        if {$path ne ""} {
            set sp [fuzzyScore $q [file tail $path]]
            if {$sp > $s} { set s $sp }
        }
        if {$s <= 0} continue
        if {$kind eq "app"} {
            set cmd [list openApp $id]
        } else {
            set cmd [list openPath $path]
        }
        lappend hits [list $s $title $cmd $kind $n]
        incr n
    }
    set hits [lsort -integer -index 0 -decreasing $hits]
    return [lrange $hits 0 13]
}
proc startTile {col row id title kind} {
    set t .desk.menu.mid.grid.t$id
    frame $t -bg #1c1c1c -width 168 -height 112 -cursor hand2
    grid $t -row $row -column $col -padx 6 -pady 6 -sticky nsew
    pack propagate $t 0
    frame $t.box -bg #2a2a2a -width 52 -height 52
    pack $t.box -pady {10 4}
    pack propagate $t.box 0
    canvas $t.box.c -width 36 -height 36 -bg #2a2a2a -highlightthickness 0
    place $t.box.c -relx 0.5 -rely 0.5 -anchor center
    drawIcon $t.box.c $kind
    label $t.n -text [shortTitle $title] -bg #1c1c1c -fg #f3f3f3 -font task -anchor center
    pack $t.n -fill x
    set idx [llength $::hitCmd]
    lappend ::hitCmd [list openApp $id]
    lappend ::hitIds $id
    foreach w [list $t $t.box $t.box.c $t.n] {
        bind $w <Button-1> [list startPick $idx]
        bind $w <Enter> [list startHover $t 1]
        bind $w <Leave> [list after 40 [list startHoverOff $t]]
    }
}
proc startHoverOff {t} {
    if {![winfo exists $t]} return
    set under ""
    catch { set under [winfo containing [winfo pointerx .] [winfo pointery .]] }
    if {$under eq $t || [string match ${t}.* $under]} return
    startHover $t 0
}
proc startTint {t on} {
    if {![winfo exists $t]} return
    set bg [expr {$on ? "#383838" : "#2a2a2a"}]
    set pg [expr {$on ? "#2a2a2a" : "#1c1c1c"}]
    $t configure -bg $pg
    if {[winfo exists $t.box]} { $t.box configure -bg $bg }
    if {[winfo exists $t.box.c]} { $t.box.c configure -bg $bg }
    if {[winfo exists $t.n]} { $t.n configure -bg $pg }
}
proc startHover {t on} {
    startTint $t $on
}
proc startHead {parent name text} {
    label $parent.$name -text $text -bg #1c1c1c -fg #9a9a9a -font tiny -anchor w
    pack $parent.$name -fill x -padx 12 -pady {10 4}
}
proc startShowHome {mid} {
    startHead $mid h1 "Закреплённые"
    frame $mid.grid -bg #1c1c1c
    pack $mid.grid -fill x
    set col 0
    set row 0
    foreach id $::startPinned {
        startTile $col $row $id [titleOf $id] [kindOf $id]
        incr col
        if {$col >= 4} { set col 0; incr row }
    }
    startHead $mid h2 "Недавние"
    if {[llength $::recent] == 0} {
        label $mid.norecent -text "Пока пусто" -bg #1c1c1c -fg #6e6e6e -font task -anchor w -padx 16
        pack $mid.norecent -fill x
    } else {
        set i 0
        foreach item $::recent {
            set title [lindex $item 0]
            set cmd [lindex $item 1]
            set when [lindex $item 2]
            set w $mid.rec$i
            frame $w -bg #1c1c1c -cursor hand2
            pack $w -fill x -padx 8
            label $w.when -text [recentWhen $when] -bg #1c1c1c -fg #8a8a8a -font tiny
            pack $w.when -side right -padx 8
            label $w.t -text $title -bg #1c1c1c -fg #f3f3f3 -font task -anchor w -padx 10 -pady 5
            pack $w.t -side left -fill x
            set idx [llength $::hitCmd]
            lappend ::hitCmd $cmd
            lappend ::hitIds rec$i
            bind $w <Button-1> [list startPick $idx]
            bind $w.t <Button-1> [list startPick $idx]
            bind $w <Enter> [list startPaint $w 1]
            bind $w <Leave> [list startPaint $w 0]
            bind $w.t <Enter> [list startPaint $w 1]
            bind $w.t <Leave> [list startPaint $w 0]
            bind $w.when <Button-1> [list startPick $idx]
            bind $w.when <Enter> [list startPaint $w 1]
            bind $w.when <Leave> [list startPaint $w 0]
            incr i
        }
    }
    frame $mid.all -bg #1c1c1c -cursor hand2
    pack $mid.all -fill x -padx 8 -pady {8 0}
    label $mid.all.t -text "Все приложения" -bg #1c1c1c -fg #f3f3f3 -font task -anchor w
    label $mid.all.a -text ">" -bg #1c1c1c -fg #c8c8c8 -font task
    pack $mid.all.a -side right -padx 10
    pack $mid.all.t -side left -padx 8 -pady 6
    bind $mid.all <Button-1> { after idle startToggleAll }
    bind $mid.all.t <Button-1> { after idle startToggleAll }
    bind $mid.all.a <Button-1> { after idle startToggleAll }
    foreach {cid cname} $::startCatNames {
        set mark ">"
        if {$::startOpen($cid)} { set mark "v" }
        frame $mid.c$cid -bg #1c1c1c -cursor hand2
        pack $mid.c$cid -fill x -padx 16
        label $mid.c$cid.m -text $mark -bg #1c1c1c -fg #c8c8c8 -font task -width 2
        label $mid.c$cid.t -text $cname -bg #1c1c1c -fg #e8e8e8 -font task -anchor w
        pack $mid.c$cid.m -side left -padx {4 0}
        pack $mid.c$cid.t -side left -fill x -pady 4
        bind $mid.c$cid <Button-1> [list after idle [list startToggle $cid]]
        bind $mid.c$cid.t <Button-1> [list after idle [list startToggle $cid]]
        bind $mid.c$cid.m <Button-1> [list after idle [list startToggle $cid]]
        if {!$::startOpen($cid)} continue
        set any 0
        foreach row $::startCatalog {
            lassign $row id title cat
            if {$cat ne $cid} continue
            set any 1
            set w $mid.a$id
            label $w -text $title -bg #1c1c1c -fg #f3f3f3 -font task -anchor w -padx 36 -pady 4 -cursor hand2
            pack $w -fill x
            set idx [llength $::hitCmd]
            lappend ::hitCmd [list openApp $id]
            lappend ::hitIds a$id
            bind $w <Button-1> [list startPick $idx]
            bind $w <Enter> [list $w configure -bg #2a2a2a]
            bind $w <Leave> [list $w configure -bg #1c1c1c]
        }
        if {!$any} {
            label $mid.empty$cid -text "Пока пусто" -bg #1c1c1c -fg #6e6e6e -font tiny -anchor w -padx 36
            pack $mid.empty$cid -fill x
        }
    }
    startHead $mid h3 "Связь"
    set i 0
    foreach row [startLinkRows] {
        lassign $row on name value
        set w $mid.lk$i
        frame $w -bg #1c1c1c
        pack $w -fill x -padx 16 -pady 1
        canvas $w.d -width 12 -height 12 -bg #1c1c1c -highlightthickness 0
        pack $w.d -side left -padx {4 6}
        set col #6a6a6a
        if {$on} { set col #3ddc84 }
        $w.d create oval 2 2 10 10 -fill $col -outline {}
        label $w.n -text "$name: $value" -bg #1c1c1c -fg #d8d8d8 -font task -anchor w
        pack $w.n -side left -fill x
        if {$name eq "DeepChat"} {
            $w configure -cursor hand2
            $w.n configure -cursor hand2
            bind $w <Button-1> { hideStart; openChat }
            bind $w.n <Button-1> { hideStart; openChat }
            bind $w.d <Button-1> { hideStart; openChat }
        }
        incr i
    }
}
proc startToggle {cid} {
    if {![info exists ::startOpen($cid)]} { set ::startOpen($cid) 0 }
    set ::startOpen($cid) [expr {1 - $::startOpen($cid)}]
    fillSearch 1
}
proc startToggleAll {} {
    set any 0
    foreach {cid cname} $::startCatNames {
        if {[info exists ::startOpen($cid)] && $::startOpen($cid)} { set any 1 }
    }
    set v [expr {!$any}]
    foreach {cid cname} $::startCatNames { set ::startOpen($cid) $v }
    fillSearch 1
}
proc startLinkRows {} {
    set ps [sh "ps 2>/dev/null"]
    set links [sh "ip -o link show 2>/dev/null"]
    set vpnOn 0
    set vpn "не подключён"
    foreach line [split $links \n] {
        if {![regexp {^[0-9]+:[[:space:]]+([^:]+):} $line -> dev]} continue
        set dev [string trim $dev]
        if {[string match tun* $dev] || [string match wg* $dev] || [string match awg* $dev] || [string match amn* $dev]} {
            set vpnOn 1
            set vpn "активен ($dev)"
        }
    }
    if {!$vpnOn && [string match -nocase *amnezia* $ps]} {
        set vpnOn 1
        set vpn "активен (Amnezia)"
    }
    set servers {}
    set local 0
    foreach line [split [readFile /etc/resolv.conf 800] \n] {
        if {[regexp {^nameserver[[:space:]]+(\S+)} $line -> ns]} {
            lappend servers $ns
            if {$ns eq "127.0.0.1" || $ns eq "::1"} { set local 1 }
        }
    }
    set dnsOn 0
    set dns "нет серверов"
    if {[llength $servers] > 0} {
        set dnsOn 1
        if {$local} {
            set dns "локальный ([join $servers {, }])"
        } else {
            set dns [join $servers {, }]
        }
    }
    set chatOn 1
    set chat "на этом компьютере"
    if {[winfo exists .wchat] && [winfo ismapped .wchat]} { set chat "открыт" }
    set stOn 0
    set st "не запущен"
    if {[string match -nocase *steam* $ps]} { set stOn 1; set st "запущен" }
    return [list [list $vpnOn VPN $vpn] [list $dnsOn DNS $dns] [list $chatOn DeepChat $chat] [list $stOn Steam $st]]
}
proc startShowResults {mid q} {
    set hits [startQuery $q]
    if {[llength $hits] == 0} {
        label $mid.empty -text "Ничего не найдено" -bg #1c1c1c -fg #8a8a8a -font task -anchor w -padx 16 -pady 16
        pack $mid.empty -fill x
        return
    }
    set i 0
    foreach h $hits {
        lassign $h score title cmd kind n
        set w $mid.r$i
        frame $w -bg #1c1c1c -cursor hand2
        pack $w -fill x -padx 8 -pady 1
        set kindText "Файл"
        if {$kind eq "app"} { set kindText "Приложение" }
        label $w.k -text $kindText -bg #1c1c1c -fg #8a8a8a -font tiny
        label $w.t -text $title -bg #1c1c1c -fg #f3f3f3 -font ui -anchor w
        pack $w.k -side right -padx 10
        pack $w.t -side left -fill x -expand 1 -padx 12 -pady 8
        lappend ::hitCmd $cmd
        lappend ::hitIds r$i
        bind $w <Button-1> [list startPick $i]
        bind $w.t <Button-1> [list startPick $i]
        bind $w.k <Button-1> [list startPick $i]
        incr i
    }
}
proc startPaint {w on} {
    if {![winfo exists $w]} return
    set bg #1c1c1c
    if {$on} { set bg #3a3328 }
    $w configure -bg $bg
    foreach c [winfo children $w] { catch { $c configure -bg $bg } }
}
proc startMarkHit {} {
    set i 0
    foreach id $::hitIds {
        set on [expr {$i == $::hit}]
        if {[winfo exists .desk.menu.mid.grid.t$id]} {
            startTint .desk.menu.mid.grid.t$id $on
        }
        if {[winfo exists .desk.menu.mid.$id]} {
            startPaint .desk.menu.mid.$id $on
        }
        incr i
    }
}
proc fillSearch {{keep 0}} {
    set mid .desk.menu.mid
    if {![winfo exists $mid]} return
    if {!$keep} { set ::hit 0 }
    set q ""
    if {[winfo exists .desk.menu.q]} { set q [string trim [.desk.menu.q get]] }
    if {[winfo exists .desk.menu.top.bar.ph]} {
        if {$q eq ""} {
            place .desk.menu.top.bar.ph -in .desk.menu.top.bar -x 42 -rely 0.5 -anchor w
        } else {
            place forget .desk.menu.top.bar.ph
        }
    }
    foreach w [winfo children $mid] { destroy $w }
    set ::hitCmd {}
    set ::hitIds {}
    if {$q eq ""} {
        startShowHome $mid
    } else {
        startShowResults $mid $q
    }
    if {[llength $::hitCmd] == 0} { set ::hit 0 }
    if {$::hit >= [llength $::hitCmd]} { set ::hit 0 }
    startMarkHit
}
proc showStart {} {
    catch { place forget .desk.power }
    if {![info exists ::startIndex] || [llength $::startIndex] == 0} { startBuildIndex }
    .desk.menu.q delete 0 end
    recentRefresh
    fillSearch
    set ::menuW 780
    set ::menuH [expr {$::SH - $::BARH - 12}]
    if {$::menuH < 640} { set ::menuH 640 }
    set ::menuStep 0
    menuGrow
    raise .desk.menu
    focus .desk.menu.q
}
proc showPower {} {
    if {![winfo ismapped .desk.menu]} { showStart; return }
    if {[winfo exists .desk.power] && [winfo ismapped .desk.power]} {
        place forget .desk.power
        return
    }
    set mx [winfo x .desk.menu]
    set my [winfo y .desk.menu]
    set mw [winfo width .desk.menu]
    set mh [winfo height .desk.menu]
    set x [expr {$mx + $mw - 250}]
    set y [expr {$my + $mh - 300}]
    if {$x < 8} { set x 8 }
    if {$y < 8} { set y 8 }
    place .desk.power -x $x -y $y -width 230 -height 280
    raise .desk.power
}
proc menuGrow {} {
    if {![winfo exists .desk.menu]} return
    incr ::menuStep
    set t [expr {$::menuStep / 7.0}]
    if {$t > 1} { set t 1 }
    set e [expr {1 - pow(1 - $t, 3)}]
    set h [expr {int(72 + ($::menuH - 72) * $e)}]
    set limit [expr {$::SH - $::BARH - 16}]
    if {$h > $limit} { set h $limit }
    set y [expr {$::SH - $::BARH - 8 - $h}]
    if {$y < 8} { set y 8 }
    place .desk.menu -x 8 -y $y -width $::menuW -height $h
    if {$t < 1} { after 16 menuGrow }
}
proc toggleStart {} {
    if {[winfo ismapped .desk.menu]} {
        hideStart
    } else {
        catch {place forget .desk.tasks}
        catch {place forget .desk.hidden}
        showStart
    }
}
proc hideStart {} {
    catch {place forget .desk.menu}
    catch {place forget .desk.power}
    catch {place forget .desk.tasks}
    catch {place forget .desk.hidden}
}
set ::superChord 0
bind all <KeyPress-Super_L> { set ::superDown 1 }
bind all <KeyPress-Super_R> { set ::superDown 1 }
bind all <KeyRelease-Super_L> {
    if {$::superChord} { set ::superChord 0 } else { toggleStart }
    break
}
bind all <KeyRelease-Super_R> {
    if {$::superChord} { set ::superChord 0 } else { toggleStart }
    break
}
bind all <Control-Escape> { toggleStart; break }
proc hotTerm {} { hideStart; openApp term }
foreach _seq {<Control-Alt-Key-t> <Control-Alt-Key-T> <Control-Alt-Key-Cyrillic_ie>} {
    bind all $_seq { hotTerm; break }
    bind Entry $_seq { hotTerm; break }
    bind Text $_seq { hotTerm; break }
}
foreach _seq {<Mod4-Key-d> <Mod4-Key-D> <Mod4-Key-Cyrillic_ve>} {
    bind all $_seq { set ::superChord 1; showDesktop; break }
    bind Entry $_seq { set ::superChord 1; showDesktop; break }
    bind Text $_seq { set ::superChord 1; showDesktop; break }
}
unset _seq
bind all <Control-Shift-Escape> { openApp monitor; break }
bind all <Control-Alt-Delete> { openApp monitor; break }
bind all <Key-Print> { takeShot; break }

frame .desk.tasks -bg #2c2c2c -highlightthickness 1 -highlightbackground #3a3a3a
frame .desk.tasks.list -bg #2c2c2c
pack .desk.tasks.list -fill both -expand 1
proc showTasks {} {
    set was [expr {[winfo exists .desk.tasks] && [winfo ismapped .desk.tasks]}]
    hideStart
    if {$was} return
    foreach w [winfo children .desk.tasks.list] { destroy $w }
    set n 0
    foreach id $::wins {
        if {![winfo exists .w$id]} continue
        incr n
        set row .desk.tasks.list.r$n
        label $row -text [titleOf $id] -bg #2c2c2c -fg #f3f3f3 -font task -anchor w -padx 14 -pady 8 -cursor hand2
        pack $row -fill x
        bind $row <Button-1> [list focusWin $id]
        bind $row <Enter> [list $row configure -bg #383838]
        bind $row <Leave> [list $row configure -bg #2c2c2c]
    }
    if {$n == 0} {
        label .desk.tasks.list.empty -text "Нет открытых окон" -bg #2c2c2c -fg #8a8a8a -font task -padx 14 -pady 10
        pack .desk.tasks.list.empty
    }
    set h [expr {($n < 1 ? 1 : $n) * 34 + 8}]
    if {$h < 44} { set h 44 }
    set y [expr {$::SH - $::BARH - 8 - $h}]
    place .desk.tasks -x 70 -y $y -width 280 -height $h
    raise .desk.tasks
}

frame .desk.hidden -bg #2c2c2c -highlightthickness 1 -highlightbackground #3a3a3a
label .desk.hidden.l -text "" -bg #2c2c2c -fg #f3f3f3 -font task -padx 12 -pady 8
pack .desk.hidden.l
proc showHidden {} {
    if {[winfo ismapped .desk.hidden]} { place forget .desk.hidden; return }
    .desk.hidden.l configure -text $::netCache
    set x [expr {[winfo rootx .desk.bar.tray.up] - [winfo rootx .desk] - 30}]
    set y [expr {$::SH - $::BARH - 40}]
    if {$x < 8} { set x 8 }
    place .desk.hidden -x $x -y $y
    raise .desk.hidden
}

frame .desk.ctx -bg #2c2c2c -highlightthickness 1 -highlightbackground #3a3a3a
proc ctxItem {name label cmd} {
    label .desk.ctx.$name -text $label -bg #2c2c2c -fg #f3f3f3 -font task -anchor w -padx 16 -pady 8
    pack .desk.ctx.$name -fill x
    bind .desk.ctx.$name <Button-1> $cmd
    bind .desk.ctx.$name <Enter> [list .desk.ctx.$name configure -bg #383838]
    bind .desk.ctx.$name <Leave> [list .desk.ctx.$name configure -bg #2c2c2c]
}
ctxItem file "Новый файл" {createEntry file}
ctxItem dir "Новая папка" {createEntry dir}
ctxItem ref "Обновить" {fillSearch; hideCtx}
ctxItem set "Настройки" {openApp settings; hideCtx}
ctxItem about "О системе" {openApp about; hideCtx}

proc hideCtx {} { place forget .desk.ctx; catch { destroy .dmenu }; clockHideSet }

proc timeFmt {{seconds 0}} {
    set h24 1
    if {[info exists ::set_h24] && $::set_h24 eq "12"} { set h24 0 }
    if {$h24} {
        if {$seconds} { return "%H:%M:%S" }
        return "%H:%M"
    }
    if {$seconds} { return "%I:%M:%S %p" }
    return "%I:%M %p"
}
proc dateFmt {} {
    if {[info exists ::set_date] && $::set_date eq "mdy"} { return "%m/%d/%Y" }
    return "%d.%m.%Y"
}
proc refreshTray {} {
    set ip [sh "ip -4 -o addr show scope global 2>/dev/null"]
    if {[regexp {inet ([0-9.]+)} $ip -> addr]} {
        set ::netCache $addr
        set col #4cc2ff
    } else {
        set ::netCache "нет сети"
        set col #6a6a6a
    }
    set now [clock seconds]
    if {[winfo exists .desk.bar.clock.t]} {
        .desk.bar.clock.t configure -text [clock format $now -format [timeFmt]]
        .desk.bar.clock.d configure -text [clock format $now -format [dateFmt]]
    }
    if {[winfo exists .desk.bar.tray.net]} {
        catch {.desk.bar.tray.net itemconfigure wave -outline $col}
        catch {.desk.bar.tray.net itemconfigure dot -fill $col}
    }
    after 1000 refreshTray
}

proc refreshIcons {} {
    fillSearch
}

proc sysinfo {} {
    set kernel [string trim [sh "uname -a"]]
    set mem ""
    foreach line [split [readFile /proc/meminfo 800] \n] {
        if {[string match MemTotal:* $line]} {
            set mem [string trim [lindex [split $line :] 1]]
        }
    }
    set ip [string trim [sh "ip -4 -o addr show scope global 2>/dev/null"]]
    set pretty "DeepOS"
    foreach line [split [readFile /etc/os-release 1500] \n] {
        if {[string match PRETTY_NAME=* $line]} {
            set pretty [string trim [string range $line 12 end] \"]
        }
    }
    return [list $kernel $mem $ip $pretty]
}

proc capBtn {id name text cmd {hot ""}} {
    set w .w$id
    label $w.in.bar.$name -text $text -bg #2c2c2c -fg #f3f3f3 -font small -width 4 -cursor hand2
    pack $w.in.bar.$name -side right -fill y
    bind $w.in.bar.$name <Button-1> "$cmd; break"
    if {$name eq "x"} {
        bind $w.in.bar.$name <Enter> [list $w.in.bar.$name configure -bg #e81123 -fg white]
        bind $w.in.bar.$name <Leave> [list $w.in.bar.$name configure -bg #2c2c2c -fg #f3f3f3]
    } else {
        bind $w.in.bar.$name <Enter> [list $w.in.bar.$name configure -bg #3d3d3d]
        bind $w.in.bar.$name <Leave> [list $w.in.bar.$name configure -bg #2c2c2c]
    }
}

proc newWindow {id title width height} {
    set w .w$id
    if {[winfo exists $w]} {
        wm deiconify $w
        raiseWin $id
        return $w
    }
    toplevel $w
    wm overrideredirect $w 1
    if {$width > $::SW - 16} { set width [expr {$::SW - 16}] }
    if {$height > $::SH - $::BARH - 16} { set height [expr {$::SH - $::BARH - 16}] }
    set x [expr {($::SW - $width) / 2}]
    set y [expr {($::SH - $::BARH - $height) / 2}]
    if {$x < 8} { set x 8 }
    if {$y < 8} { set y 8 }
    wm geometry $w ${width}x${height}+$x+$y
    $w configure -bg #3a3a3a
    frame $w.in -bg $::MICA
    pack $w.in -fill both -expand 1 -padx 1 -pady 1
    frame $w.in.bar -bg #2c2c2c -height 34 -cursor fleur
    pack $w.in.bar -fill x
    pack propagate $w.in.bar 0
    capBtn $id x "×" [list closeWin $id]
    capBtn $id m "□" [list maxWin $id]
    capBtn $id n "–" [list minWin $id]
    label $w.in.bar.h -text $title -bg #2c2c2c -fg #f3f3f3 -font small -anchor w -cursor fleur
    pack $w.in.bar.h -side left -fill both -expand 1 -padx 12
    frame $w.in.b -bg $::MICA
    pack $w.in.b -fill both -expand 1
    bind $w.in.bar <ButtonPress-1> [list beginDrag $w %X %Y]
    bind $w.in.bar.h <ButtonPress-1> [list beginDrag $w %X %Y]
    bind $w.in.bar <B1-Motion> { dragMotion %X %Y }
    bind $w.in.bar.h <B1-Motion> { dragMotion %X %Y }
    bind $w.in.bar <Double-Button-1> [list maxWin $id]
    bind $w.in.bar.h <Double-Button-1> [list maxWin $id]
    bind $w <Button-1> [list raiseWin $id]
    placeGrips $w
    lappend ::wins $id
    set ::title($id) $title
    set ::geom($id) ${width}x${height}+$x+$y
    set ::max($id) 0
    set ::active $id
    paintPins
    clockRaise
    return $w
}
proc raiseWin {id} {
    if {![winfo exists .w$id]} return
    set ::active $id
    raise .w$id
    if {[info exists ::pintitle($id)]} {
        noteRecent [titleOf $id] [list openApp $id]
    }
    if {[winfo exists .ask]} { raise .ask }
    if {[winfo exists .fmenu]} { raise .fmenu }
    paintPins
    clockRaise
    if {$id eq "term" && [winfo exists .wterm.in.b.t]} { focus .wterm.in.b.t }
}
proc winBox {w} {
    set ww [winfo width $w]
    set hh [winfo height $w]
    if {$ww < 50 || $hh < 50} {
        regexp {^([0-9]+)x([0-9]+)} [wm geometry $w] -> ww hh
    }
    return [list $ww $hh]
}
proc placeGrips {w} {
    foreach {name edge cursor} {
        gn n top_side
        gs s bottom_side
        ge e right_side
        gw w left_side
        gnw nw top_left_corner
        gne ne top_right_corner
        gsw sw bottom_left_corner
        gse se bottom_right_corner
    } {
        if {[catch {frame $w.$name -bg #3a3a3a -cursor $cursor}]} {
            frame $w.$name -bg #3a3a3a
        }
        bind $w.$name <ButtonPress-1> [list beginResize $w $edge %X %Y]
    }
    set t 4
    set c 8
    place $w.gn -relx 0 -x $c -y 0 -relwidth 1 -width [expr {-$c * 2}] -height $t
    place $w.gs -relx 0 -x $c -rely 1 -y -$t -relwidth 1 -width [expr {-$c * 2}] -height $t
    place $w.gw -x 0 -y $c -width $t -relheight 1 -height [expr {-$c * 2}]
    place $w.ge -relx 1 -x -$t -y $c -width $t -relheight 1 -height [expr {-$c * 2}]
    place $w.gnw -x 0 -y 0 -width $c -height $c
    place $w.gne -relx 1 -x -$c -y 0 -width $c -height $c
    place $w.gsw -x 0 -rely 1 -y -$c -width $c -height $c
    place $w.gse -relx 1 -x -$c -rely 1 -y -$c -width $c -height $c
    foreach name {gn gs ge gw gnw gne gsw gse} { raise $w.$name }
}
proc beginDrag {w x y} {
    lassign [winBox $w] ww hh
    set ::dragW $w
    set ::dragMode move
    set ::dragX $x
    set ::dragY $y
    set ::dragMoved 0
    set ::origX [winfo rootx $w]
    set ::origY [winfo rooty $w]
    set ::origW $ww
    set ::origH $hh
    raiseWin [string range $w 2 end]
    catch { grab set $w }
}
proc beginResize {w edge x y} {
    set id [string range $w 2 end]
    if {[info exists ::max($id)] && $::max($id)} return
    lassign [winBox $w] ww hh
    set ::dragW $w
    set ::dragMode resize
    set ::dragEdge $edge
    set ::dragX $x
    set ::dragY $y
    set ::dragMoved 0
    set ::origX [winfo rootx $w]
    set ::origY [winfo rooty $w]
    set ::origW $ww
    set ::origH $hh
    raiseWin $id
}
proc dragMotion {x y} {
    if {[info exists ::clkGrab] && $::clkGrab} {
        clockDrag $x $y
        return
    }
    if {[info exists ::deskGrab] && $::deskGrab ne ""} {
        deskMove $x $y
        return
    }
    if {![info exists ::dragW] || $::dragW eq ""} return
    if {![winfo exists $::dragW]} { set ::dragW ""; return }
    if {!$::dragMoved} {
        if {abs($x - $::dragX) + abs($y - $::dragY) < 3} return
        set ::dragMoved 1
    }
    if {$::dragMode eq "resize"} {
        dragResize $::dragW $x $y
    } else {
        dragMove $::dragW $x $y
    }
}
proc dragMove {w x y} {
    set id [string range $w 2 end]
    if {[info exists ::max($id)] && $::max($id)} {
        set ww 900
        set hh 580
        if {[info exists ::geom($id)] && [regexp {^([0-9]+)x([0-9]+)} $::geom($id) -> ww hh]} {}
        set nx [expr {$x - $ww / 2}]
        set ny [expr {$y - 18}]
        if {$nx < 0} { set nx 0 }
        if {$ny < 0} { set ny 0 }
        set ::max($id) 0
        set ::origX $nx
        set ::origY $ny
        set ::origW $ww
        set ::origH $hh
        set ::dragX $x
        set ::dragY $y
        wm geometry $w [format "%dx%d+%d+%d" $ww $hh $nx $ny]
        return
    }
    set nx [expr {$::origX + ($x - $::dragX)}]
    set ny [expr {$::origY + ($y - $::dragY)}]
    if {$nx > $::SW - 80} { set nx [expr {$::SW - 80}] }
    if {$ny > $::SH - $::BARH - 36} { set ny [expr {$::SH - $::BARH - 36}] }
    if {$nx < [expr {80 - $::origW}]} { set nx [expr {80 - $::origW}] }
    if {$ny < 0} { set ny 0 }
    wm geometry $w [format "%dx%d+%d+%d" $::origW $::origH $nx $ny]
}
proc dragResize {w x y} {
    set dx [expr {$x - $::dragX}]
    set dy [expr {$y - $::dragY}]
    set nx $::origX
    set ny $::origY
    set nw $::origW
    set nh $::origH
    set e $::dragEdge
    if {[string first e $e] >= 0} { set nw [expr {$nw + $dx}] }
    if {[string first s $e] >= 0} { set nh [expr {$nh + $dy}] }
    if {[string first w $e] >= 0} {
        set nw [expr {$nw - $dx}]
        set nx [expr {$nx + $dx}]
    }
    if {[string first n $e] >= 0} {
        set nh [expr {$nh - $dy}]
        set ny [expr {$ny + $dy}]
    }
    if {$ny < 0} {
        if {[string first n $e] >= 0} { set nh [expr {$nh + $ny}] }
        set ny 0
    }
    if {$nx < 0} {
        if {[string first w $e] >= 0} { set nw [expr {$nw + $nx}] }
        set nx 0
    }
    if {$nw < 420} {
        if {[string first w $e] >= 0} { set nx [expr {$nx + $nw - 420}] }
        set nw 420
    }
    if {$nh < 300} {
        if {[string first n $e] >= 0} { set ny [expr {$ny + $nh - 300}] }
        set nh 300
    }
    if {$nw > $::SW} { set nw $::SW }
    if {$nh > $::SH - $::BARH} { set nh [expr {$::SH - $::BARH}] }
    wm geometry $w [format "%dx%d+%d+%d" $nw $nh $nx $ny]
}
proc dragRelease {} {
    if {[info exists ::clkGrab] && $::clkGrab} {
        set moved 0
        if {[info exists ::clkDrag]} { set moved $::clkDrag }
        set ::clkGrab 0
        set ::clkDrag 0
        if {$moved} { clockSave } else { openCalendar }
        return
    }
    if {[info exists ::deskGrab] && $::deskGrab ne ""} {
        set f $::deskGrab
        set ::deskGrab ""
        deskDrop $f
        return
    }
    set w ""
    if {[info exists ::dragW]} { set w $::dragW }
    set ::dragW ""
    if {$w ne ""} { catch { grab release $w } }
    if {$w eq "" || ![winfo exists $w]} return
    set id [string range $w 2 end]
    if {![info exists ::max($id)] || !$::max($id)} {
        set ::geom($id) [wm geometry $w]
    }
}
bind all <B1-Motion> { dragMotion %X %Y }
bind all <ButtonRelease-1> { dragRelease }
proc closeWin {id} {
    if {[info exists ::dragW] && $::dragW eq ".w$id"} { set ::dragW "" }
    if {$id eq "files"} { catch { filesMenuHide } }
    if {$id eq "browse"} {
        sunStopAll
        # NetSurf may reappear on the root after the Tk host dies — kill again.
        catch {exec sh -c {for p in $(pidof netsurf netsurf-gtk nsgtk 2>/dev/null); do kill -KILL $p 2>/dev/null; done}}
    }
    if {$id eq "firefox" || $id eq "chrome" || [string match exe* $id] || [string match app* $id]} { hostStop $id }
    destroy .w$id
    set ::wins [lsearch -all -inline -not -exact $::wins $id]
    if {$::active eq $id} { set ::active "" }
    paintPins
}
proc minWin {id} {
    wm withdraw .w$id
    if {$::active eq $id} { set ::active "" }
    paintPins
}
proc maxWin {id} {
    set w .w$id
    if {$::max($id)} {
        wm geometry $w $::geom($id)
        set ::max($id) 0
    } else {
        set ::geom($id) [wm geometry $w]
        set sw [winfo screenwidth .desk]
        set sh [expr {[winfo screenheight .desk] - $::BARH}]
        wm geometry $w ${sw}x${sh}+0+0
        set ::max($id) 1
    }
}

proc openApp {id} {
    hideStart
    hideCtx
    if {$id ne "power"} {
        noteRecent [titleOf $id] [list openApp $id]
        speak [titleOf $id]
    }
    switch $id {
        term { openTerm }
        files { openFiles /root }
        pc { openPC }
        trash { openTrash }
        browse { openBrowse }
        firefox { openFirefox }
        chrome { openChrome }
        settings { openSettings }
        sound { openSettings sound }
        about { openAbout }
        calendar { openCalendar }
        power { shutdown }
        pkgs { openPackages }
        monitor { openMonitor }
        log { openLog }
        shot { takeShot }
        updates { openUpdates }
        chat { openChat }
        gstore { openGStore }
    }
}
proc chatReload {} {
    set t .wchat.in.b.log
    if {![winfo exists $t]} return
    $t tag configure when -foreground #8a8a8a
    $t configure -state normal
    $t delete 1.0 end
    set raw ""
    if {[file exists /root/.deepos/deepchat]} { set raw [readFile /root/.deepos/deepchat 200000] }
    if {[string trim $raw] eq ""} {
        $t insert end "Пока пусто. Напишите сообщение — оно останется на этом компьютере."
    } else {
        foreach line [split $raw \n] {
            if {$line eq ""} continue
            set bits [split $line \t]
            set when [lindex $bits 0]
            set msg [join [lrange $bits 1 end] \t]
            $t insert end "$when  " when
            $t insert end "$msg\n"
        }
    }
    $t configure -state disabled
    $t see end
}
proc chatSend {} {
    set e .wchat.in.b.row.e
    if {![winfo exists $e]} return
    set msg [string trim [$e get]]
    set msg [string map [list \t " " \n " "] $msg]
    if {$msg eq ""} return
    $e delete 0 end
    file mkdir /root/.deepos
    set fh [open /root/.deepos/deepchat a]
    puts $fh "[clock format [clock seconds] -format {%d.%m %H:%M}]\t$msg"
    close $fh
    chatReload
}
proc openChat {} {
    set w [newWindow chat "DeepChat" 760 520]
    set b $w.in.b
    if {[winfo exists $b.log]} {
        chatReload
        focus $b.row.e
        return
    }
    $b configure -bg #1c1c1c
    label $b.h -text "DeepChat" -bg #1c1c1c -fg #ffffff -font title -anchor w
    pack $b.h -fill x -padx 16 -pady {12 0}
    label $b.sub -text "Сообщения этого компьютера. Они сохраняются здесь и никуда не отправляются." \
        -bg #1c1c1c -fg #9a9a9a -font small -anchor w -wraplength 700 -justify left
    pack $b.sub -fill x -padx 16 -pady {2 0}
    text $b.log -bg #141414 -fg #f3f3f3 -font ui -wrap word -highlightthickness 0 \
        -state disabled -padx 12 -pady 10 -insertwidth 0 -cursor arrow
    pack $b.log -fill both -expand 1 -padx 16 -pady 8
    frame $b.row -bg #1c1c1c
    pack $b.row -fill x -padx 16 -pady {0 14}
    entry $b.row.e -bg #2a2a2a -fg #ffffff -insertbackground #ffffff -font ui -bd 0 \
        -highlightthickness 1 -highlightbackground #3a3a3a -highlightcolor #e4c4a0
    pack $b.row.e -side left -fill x -expand 1 -ipady 8 -padx {0 8}
    label $b.row.go -text "Отправить" -bg #e4c4a0 -fg #1c1612 -font ui -padx 14 -pady 6 -cursor hand2
    pack $b.row.go -side right
    bind $b.row.go <Button-1> chatSend
    bind $b.row.e <Return> chatSend
    chatReload
    focus $b.row.e
}
proc openPath {path} {
    hideStart
    hideCtx
    noteRecent [file tail $path] [list openPath $path]
    if {[file isdirectory $path]} { openFiles $path } else { openByType $path }
}

proc termFont {} {
    if {[lsearch -exact [font names] termfont] < 0} {
        font create termfont -family "Cascadia Mono" -size 14
    }
    if {![string match -nocase *cascadia* [font actual termfont -family]]} {
        font configure termfont -family "DejaVu Sans Mono" -size 13
    }
}
proc openTerm {} {
    set w [newWindow term "Терминал" 920 560]
    set b $w.in.b
    if {[winfo exists $b.t]} {
        termApplyColors
        focus -force $b.t
        $b.t mark set insert end
        return
    }
    termFont
    $w.in configure -bg #0c0c0c
    $b configure -bg #0c0c0c
    frame $b.tabs -bg #181818 -height 36
    pack $b.tabs -side top -fill x
    pack propagate $b.tabs 0
    frame $b.tabs.tab -bg #0c0c0c
    pack $b.tabs.tab -side left -fill y -padx {10 0} -pady {6 0}
    frame $b.tabs.tab.bar -bg #0078d4 -height 2
    pack $b.tabs.tab.bar -fill x
    label $b.tabs.tab.n -text "  DeepOS  " -bg #0c0c0c -fg #f2f2f2 -font small
    pack $b.tabs.tab.n -pady {4 6}
    label $b.tabs.plus -text "+" -bg #181818 -fg #cccccc -font ui -padx 12 -cursor hand2
    pack $b.tabs.plus -side left -pady {8 0}
    bind $b.tabs.plus <Button-1> { focus -force .wterm.in.b.t }
    bind $b.tabs <Button-1> { focus -force .wterm.in.b.t }
    text $b.t -bg #0c0c0c -fg #cccccc -insertbackground #cccccc -font termfont \
        -highlightthickness 0 -borderwidth 0 -padx 18 -pady 14 \
        -wrap char -undo 0 -spacing1 2 \
        -selectbackground #264f78 -selectforeground #ffffff
    catch { $b.t configure -blockcursor 1 }
    pack $b.t -fill both -expand 1
    $b.t tag configure puser -foreground #16c60c
    $b.t tag configure ppath -foreground #3b78ff
    $b.t tag configure pdol -foreground #cccccc
    $b.t tag configure out -foreground #cccccc
    $b.t tag configure err -foreground #e74856
    $b.t tag configure banner -foreground #f2f2f2
    set ::termHist {}
    set ::termHistI 0
    set info [sysinfo]
    set pretty [lindex $info 3]
    $b.tabs.tab.n configure -text "  $pretty  "
    $w.in.bar.h configure -text "Терминал  ·  $pretty"
    $b.t insert end "$pretty\n" banner
    $b.t insert end "[lindex $info 0]\n\n" out
    termPrompt
    bind $b.t <KeyPress> { termOnKey %A %K %s; break }
    bind $b.t <Button-1> {+ after idle { if {[winfo exists .wterm.in.b.t]} { focus -force .wterm.in.b.t } } }
    termApplyColors
    focus -force $b.t
}
proc termApplyColors {} {
    set bg #0c0c0c
    set fg #cccccc
    if {[info exists ::set_termbg] && $::set_termbg ne ""} { set bg $::set_termbg }
    if {[info exists ::set_termfg] && $::set_termfg ne ""} { set fg $::set_termfg }
    set t .wterm.in.b.t
    if {![winfo exists $t]} return
    $t configure -bg $bg -fg $fg -insertbackground $fg
    catch { $t tag configure out -foreground $fg }
    catch { $t tag configure pdol -foreground $fg }
    set b .wterm.in.b
    catch { $b configure -bg $bg }
    catch { .wterm.in configure -bg $bg }
}
proc termPrompt {} {
    set t .wterm.in.b.t
    if {![winfo exists $t]} return
    $t insert end "$::user@$::host" puser
    $t insert end ":" pdol
    $t insert end $::cwd ppath
    $t insert end " \$ " pdol
    $t mark set termIn "end-1c"
    $t mark gravity termIn left
    $t mark set insert end
    $t see end
}
proc termInput {} {
    set t .wterm.in.b.t
    if {[$t compare insert < termIn]} { $t mark set insert end }
}
proc termOnKey {char key state} {
    set t .wterm.in.b.t
    if {![winfo exists $t]} return
    termInput
    set ctrl [expr {($state & 4) != 0}]
    if {$key eq "Return" || $key eq "KP_Enter"} { termRun; return }
    if {$ctrl && ($key eq "c" || $key eq "C")} {
        if {[$t tag ranges sel] ne ""} {
            clipboard clear
            clipboard append [$t get sel.first sel.last]
            return
        }
        $t insert end "^C" err
        $t insert end \n out
        termPrompt
        return
    }
    if {$ctrl && ($key eq "l" || $key eq "L")} {
        $t delete 1.0 end
        termPrompt
        return
    }
    if {$ctrl && ($key eq "v" || $key eq "V")} {
        if {![catch {clipboard get} clip]} {
            regsub -all {\r\n|\n|\r} $clip " " clip
            $t insert insert $clip out
        }
        return
    }
    if {$key eq "BackSpace"} {
        if {[$t compare insert > termIn]} { $t delete insert-1c }
        return
    }
    if {$key eq "Delete"} {
        if {[$t compare insert >= termIn] && [$t compare insert < end-1c]} { $t delete insert }
        return
    }
    if {$key eq "Left"} {
        if {[$t compare insert > termIn]} { $t mark set insert insert-1c }
        return
    }
    if {$key eq "Right"} {
        if {[$t compare insert < end-1c]} { $t mark set insert insert+1c }
        return
    }
    if {$key eq "Home"} { $t mark set insert termIn; return }
    if {$key eq "End"} { $t mark set insert end; return }
    if {$key eq "Up"} { termHist -1; return }
    if {$key eq "Down"} { termHist 1; return }
    if {$ctrl} return
    if {$char eq "" || [string is control -strict $char]} return
    $t insert insert $char out
}
proc termHist {dir} {
    if {![info exists ::termHist] || [llength $::termHist] == 0} return
    set n [llength $::termHist]
    set i [expr {$::termHistI + $dir}]
    if {$i < 0} { set i 0 }
    if {$i > $n} { set i $n }
    set ::termHistI $i
    set t .wterm.in.b.t
    $t delete termIn end
    if {$i < $n} { $t insert end [lindex $::termHist $i] out }
    $t mark set insert end
    $t see end
}
proc termQuote {s} {
    return "'[string map {' '\\''} $s]'"
}
proc termRun {} {
    set t .wterm.in.b.t
    set cmd [string trim [$t get termIn end-1c]]
    $t insert end \n out
    if {$cmd ne ""} {
        lappend ::termHist $cmd
        set ::termHistI [llength $::termHist]
        if {[regexp {^cd(?:\s+(.*))?$} $cmd -> dir]} {
            if {$dir eq "" || $dir eq "~"} { set dir /root }
            if {![string match /* $dir]} { set dir [file join $::cwd $dir] }
            set dir [file normalize $dir]
            if {[file isdirectory $dir]} {
                set ::cwd $dir
            } else {
                $t insert end "нет такого каталога: $dir\n" err
            }
        } else {
            set script "cd [termQuote $::cwd] && $cmd"
            set code [catch {exec /bin/sh -c $script 2>@1} out]
            if {$out ne ""} {
                set tag out
                if {$code} { set tag err }
                $t insert end $out\n $tag
            }
        }
    }
    termPrompt
}

proc openFiles {path} {
    set w [newWindow files "Файлы" 1020 660]
    filesEnsure $w
    filesGo $path
}
proc filesEnsure {w} {
    set b $w.in.b
    if {[winfo exists $b.ribbon]} return
    $b configure -bg #f5f6f7
    set ::filesSort name
    set ::filesSortDir 1
    set ::filesSel ""
    set ::filesFilter ""
    set ::filesClip ""
    set ::filesClipOp ""
    set ::filesHoverRow -1
    set ::filesHist {}
    set ::filesI -1
    set ::filesAll {}
    set ::filesRows {}
    frame $b.ribbon -bg #f5f6f7
    pack $b.ribbon -side top -fill x
    frame $b.ribbon.tabs -bg #f5f6f7 -height 28
    pack $b.ribbon.tabs -fill x
    pack propagate $b.ribbon.tabs 0
    frame $b.ribbon.tabs.home -bg #f5f6f7
    pack $b.ribbon.tabs.home -side left -padx 12
    label $b.ribbon.tabs.home.t -text "Главная" -bg #f5f6f7 -fg #1a1a1a -font small
    pack $b.ribbon.tabs.home.t -pady {6 2}
    frame $b.ribbon.tabs.home.u -bg #0078d7 -height 2
    pack $b.ribbon.tabs.home.u -fill x
    frame $b.ribbon.rule -bg #e5e5e5 -height 1
    pack $b.ribbon.rule -fill x
    frame $b.ribbon.tools -bg #f5f6f7 -height 64
    pack $b.ribbon.tools -fill x
    pack propagate $b.ribbon.tools 0
    filesTool $b.ribbon.tools new "Новая папка" filesNewDir new
    filesTool $b.ribbon.tools del "Удалить" filesDelete del
    filesTool $b.ribbon.tools ren "Переименовать" filesRename ren
    filesSep $b.ribbon.tools s1
    filesTool $b.ribbon.tools copy "Копировать" filesCopy copy
    filesTool $b.ribbon.tools cut "Вырезать" filesCut cut
    filesTool $b.ribbon.tools paste "Вставить" filesPaste paste
    filesSep $b.ribbon.tools s2
    filesTool $b.ribbon.tools refresh "Обновить" filesRefresh refresh
    filesTool $b.ribbon.tools prop "Свойства" filesProps prop
    frame $b.nav -bg #f5f6f7 -height 42
    pack $b.nav -side top -fill x
    pack propagate $b.nav 0
    foreach {name text} {back "←" fwd "→" up "↑"} {
        label $b.nav.$name -text $text -bg #f5f6f7 -fg #1a1a1a -font uib -width 2 -cursor hand2
        pack $b.nav.$name -side left -padx 1 -pady 4
    }
    bind $b.nav.back <Button-1> { filesBack; break }
    bind $b.nav.fwd <Button-1> { filesFwd; break }
    bind $b.nav.up <Button-1> { filesUp; break }
    bind $b.nav.back <Enter> { .wfiles.in.b.nav.back configure -bg #e5f1fb }
    bind $b.nav.back <Leave> { .wfiles.in.b.nav.back configure -bg #f5f6f7 }
    bind $b.nav.fwd <Enter> { .wfiles.in.b.nav.fwd configure -bg #e5f1fb }
    bind $b.nav.fwd <Leave> { .wfiles.in.b.nav.fwd configure -bg #f5f6f7 }
    bind $b.nav.up <Enter> { .wfiles.in.b.nav.up configure -bg #e5f1fb }
    bind $b.nav.up <Leave> { .wfiles.in.b.nav.up configure -bg #f5f6f7 }
    frame $b.nav.q -bg #ffffff -highlightthickness 1 -highlightbackground #b4b4b4
    pack $b.nav.q -side right -padx {0 10} -pady 7
    label $b.nav.q.l -text "Поиск" -bg #ffffff -fg #8a8a8a -font small
    pack $b.nav.q.l -side left -padx {8 0}
    entry $b.nav.q.e -bg #ffffff -fg #1a1a1a -font small -width 18 -bd 0 \
        -insertbackground #0078d7 -highlightthickness 0 -relief flat
    pack $b.nav.q.e -side left -padx 6 -pady 3 -ipady 2
    bind $b.nav.q.e <KeyRelease> filesSearch
    frame $b.nav.addr -bg #ffffff -highlightthickness 1 -highlightbackground #b4b4b4
    pack $b.nav.addr -side left -fill both -expand 1 -padx 8 -pady 7
    bind $b.nav.addr <Button-1> filesAddrEdit
    entry $b.nav.addr.e -bg #ffffff -fg #1a1a1a -font small -bd 0 -relief flat \
        -insertbackground #0078d7 -highlightthickness 0
    bind $b.nav.addr.e <Return> filesAddrGo
    bind $b.nav.addr.e <Escape> filesAddrCancel
    frame $b.stat -bg #f5f6f7 -height 28
    pack $b.stat -side bottom -fill x
    pack propagate $b.stat 0
    frame $b.stat.line -bg #e5e5e5 -height 1
    place $b.stat.line -relx 0 -rely 0 -relwidth 1 -height 1
    label $b.stat.n -text "" -bg #f5f6f7 -fg #1a1a1a -font small -anchor w
    place $b.stat.n -x 12 -rely 0.5 -anchor w
    label $b.stat.s -text "" -bg #f5f6f7 -fg #666666 -font small -anchor e
    place $b.stat.s -relx 1 -x -12 -rely 0.5 -anchor e
    frame $b.body -bg #ffffff
    pack $b.body -fill both -expand 1
    frame $b.body.side -bg #f5f6f7 -width 230
    pack $b.body.side -side left -fill y
    pack propagate $b.body.side 0
    canvas $b.body.side.c -bg #f5f6f7 -highlightthickness 0 -bd 0
    pack $b.body.side.c -fill both -expand 1
    bind $b.body.side.c <Button-4> { %W yview scroll -3 units }
    bind $b.body.side.c <Button-5> { %W yview scroll 3 units }
    frame $b.body.sep -bg #e5e5e5 -width 1
    pack $b.body.sep -side left -fill y
    pack propagate $b.body.sep 0
    frame $b.body.main -bg #ffffff
    pack $b.body.main -side left -fill both -expand 1
    frame $b.body.main.head -bg #ffffff -height 30
    pack $b.body.main.head -side top -fill x
    pack propagate $b.body.main.head 0
    frame $b.body.main.head.line -bg #e5e5e5 -height 1
    place $b.body.main.head.line -rely 1 -y -1 -relwidth 1 -height 1
    foreach {nm anchor} {name w date w type w size e} {
        label $b.body.main.head.$nm -text "" -bg #ffffff -fg #4a4a4a -font small -anchor $anchor -cursor hand2
        bind $b.body.main.head.$nm <Button-1> [list filesSortBy $nm]
    }
    frame $b.body.main.list -bg #ffffff
    pack $b.body.main.list -fill both -expand 1
    canvas $b.body.main.c -bg #ffffff -highlightthickness 0 -bd 0
    scrollbar $b.body.main.sb -command [list $b.body.main.c yview] -bd 0 \
        -bg #f0f0f0 -troughcolor #ffffff -activebackground #c8c8c8 -highlightthickness 0
    $b.body.main.c configure -yscrollcommand [list $b.body.main.sb set]
    pack $b.body.main.sb -in $b.body.main.list -side right -fill y
    pack $b.body.main.c -in $b.body.main.list -side left -fill both -expand 1
    bind $b.body.main.c <Configure> filesLayout
    bind $b.body.main.c <Button-4> { %W yview scroll -3 units }
    bind $b.body.main.c <Button-5> { %W yview scroll 3 units }
    bind $b.body.main.c <Motion> { filesMotion %x %y }
    bind $b.body.main.c <Leave> filesLeave
    bind $b.body.main.c <Button-1> { filesBackgroundClick %x %y }
    bind $b.body.main.c <Button-3> { filesMenu %X %Y %x %y }
    bind $b.body.main.c <Delete> filesDelete
    bind $b.body.main.c <BackSpace> filesUp
    bind $b.body.main.c <Return> filesActivateSel
    bind $b.body.main.c <Up> { filesMove -1 }
    bind $b.body.main.c <Down> { filesMove 1 }
    bind $b.body.main.c <F2> filesRename
    bind $b.body.main.c <F5> filesRefresh
    bind $b.body.main.c <Control-c> filesCopy
    bind $b.body.main.c <Control-x> filesCut
    bind $b.body.main.c <Control-v> filesPaste
    bind .wfiles <Alt-Left> filesBack
    bind .wfiles <Alt-Right> filesFwd
    bind .wfiles <Alt-Up> filesUp
    bind .wfiles <F5> filesRefresh
    bind .wfiles <Button-1> +filesMenuHide
    update idletasks
}
proc filesTool {parent name text cmd kind} {
    set f $parent.$name
    frame $f -bg #f5f6f7 -cursor hand2
    pack $f -side left -padx 2 -pady 4
    canvas $f.i -width 24 -height 22 -bg #f5f6f7 -highlightthickness 0 -cursor hand2
    pack $f.i
    filesGlyph $f.i $kind
    label $f.t -text $text -bg #f5f6f7 -fg #1a1a1a -font tiny -cursor hand2
    pack $f.t
    foreach widget [list $f $f.i $f.t] {
        bind $widget <Button-1> [list filesToolRun $cmd]
        bind $widget <Enter> [list filesToolHot $f 1]
        bind $widget <Leave> [list filesToolHot $f 0]
    }
}
proc filesToolRun {cmd} {
    filesMenuHide
    after idle $cmd
}
proc filesToolHot {f on} {
    set bg #f5f6f7
    if {$on} { set bg #e5f1fb }
    $f configure -bg $bg
    foreach c [winfo children $f] {
        catch { $c configure -bg $bg }
    }
}
proc filesSep {parent name} {
    frame $parent.$name -bg #d0d0d0 -width 1
    pack $parent.$name -side left -fill y -padx 6 -pady 10
    pack propagate $parent.$name 0
}
proc filesGlyph {c kind} {
    $c delete all
    switch -- $kind {
        new {
            $c create polygon 2 8 8 8 10 6 20 6 20 18 2 18 -fill #ffc83d -outline #e1a800
        }
        del {
            $c create rectangle 7 8 16 18 -fill #e81123 -outline #c50f1f
            $c create line 5 7 18 7 -fill #4a4a4a -width 2
            $c create line 9 5 14 5 -fill #4a4a4a -width 2
        }
        ren {
            $c create line 5 16 15 6 -fill #0078d7 -width 2
            $c create polygon 14 4 19 9 15 8 -fill #0078d7
        }
        copy {
            $c create rectangle 8 3 19 15 -fill #ffffff -outline #5b5b5b
            $c create rectangle 4 7 15 19 -fill #ffffff -outline #5b5b5b
        }
        cut {
            $c create line 4 12 20 12 -fill #5b5b5b -width 2
            $c create line 7 8 12 16 -fill #c0c0c0 -width 2
            $c create line 17 8 12 16 -fill #5b5b5b -width 2
        }
        paste {
            $c create rectangle 6 5 16 18 -fill #ffffff -outline #5b5b5b
            $c create rectangle 8 3 14 7 -fill #0078d7 -outline #0078d7
        }
        refresh {
            $c create arc 4 4 18 18 -start 50 -extent 270 -style arc -outline #0078d7 -width 2
            $c create polygon 15 3 20 5 16 9 -fill #0078d7
        }
        prop {
            $c create oval 4 4 18 18 -outline #0078d7 -width 2
            $c create text 11 12 -text i -fill #0078d7 -font uib
        }
    }
}
proc filesGo {path {push 1}} {
    if {$path eq "pc:"} { openPC; return }
    if {$path eq "trash:"} { openTrash; return }
    if {![file isdirectory $path]} return
    set path [file normalize $path]
    if {![info exists ::filesHist]} { set ::filesHist {}; set ::filesI -1 }
    if {$push} {
        if {$::filesI < 0 || [lindex $::filesHist $::filesI] ne $path} {
            set ::filesHist [lrange $::filesHist 0 $::filesI]
            lappend ::filesHist $path
            set ::filesI [expr {[llength $::filesHist] - 1}]
        }
    }
    set ::filesPath $path
    set ::filesSel ""
    set ::filesFilter ""
    set ::filesEditing 0
    set ::filesNote ""
    set ::filesResetScroll 1
    set e .wfiles.in.b.nav.q.e
    if {[winfo exists $e]} { $e delete 0 end }
    filesMenuHide
    filesRender
    set c .wfiles.in.b.body.main.c
    if {[winfo exists $c]} { focus $c }
}
proc filesBack {} {
    if {![info exists ::filesI] || $::filesI <= 0} return
    incr ::filesI -1
    filesGo [lindex $::filesHist $::filesI] 0
}
proc filesFwd {} {
    if {![info exists ::filesI]} return
    if {$::filesI >= [llength $::filesHist] - 1} return
    incr ::filesI
    filesGo [lindex $::filesHist $::filesI] 0
}
proc filesUp {} {
    if {![info exists ::filesPath] || $::filesPath eq "/"} return
    filesGo [file dirname $::filesPath]
}
proc filesRefresh {} {
    if {![info exists ::filesPath]} return
    filesGo $::filesPath 0
}
proc filesRender {} {
    filesLoad
    filesRenderNav
    filesRenderCrumbs
    filesChrome
    set ::filesColW -1
    set ::filesNeedList 1
    filesLayout
    filesRenderStatus
}
proc filesLoad {} {
    set ::filesAll {}
    set ::filesDenied 0
    set path $::filesPath
    if {![file isdirectory $path] || ![file readable $path]} {
        set ::filesDenied 1
        filesApplyFilter
        return
    }
    set names {}
    catch { set names [lsort [glob -nocomplain -directory $path *]] }
    foreach f $names {
        set base [file tail $f]
        if {$base eq "" || [string match .* $base]} continue
        set isdir [file isdirectory $f]
        set mtime 0
        set size 0
        catch { set mtime [file mtime $f] }
        if {!$isdir} { catch { set size [file size $f] } }
        lappend ::filesAll [list $base $f $isdir $mtime $size [filesKind $f $isdir]]
    }
    filesApplyFilter
}
proc filesApplyFilter {} {
    if {![info exists ::filesSort]} { set ::filesSort name }
    if {![info exists ::filesSortDir]} { set ::filesSortDir 1 }
    if {![info exists ::filesFilter]} { set ::filesFilter "" }
    if {![info exists ::filesAll]} { set ::filesAll {} }
    set q [string tolower $::filesFilter]
    set rows {}
    foreach row $::filesAll {
        set name [string tolower [lindex $row 0]]
        if {$q eq "" || [string first $q $name] >= 0} { lappend rows $row }
    }
    set ::filesRows [lsort -command filesItemSort $rows]
}
proc filesItemSort {a b} {
    set da [lindex $a 2]
    set db [lindex $b 2]
    if {$da && !$db} { return -1 }
    if {!$da && $db} { return 1 }
    set r 0
    switch -- $::filesSort {
        date { set r [expr {[lindex $a 3] - [lindex $b 3]}] }
        size { set r [expr {[lindex $a 4] - [lindex $b 4]}] }
        type { set r [string compare -nocase [lindex $a 5] [lindex $b 5]] }
        default { set r [string compare -nocase [lindex $a 0] [lindex $b 0]] }
    }
    if {$r == 0} { return 0 }
    if {$::filesSortDir < 0} { return [expr {$r > 0 ? -1 : 1}] }
    return [expr {$r > 0 ? 1 : -1}]
}
proc filesKind {path dir} {
    if {$dir} { return "Папка" }
    set ext [string tolower [file extension $path]]
    switch -- $ext {
        .txt - .md - .log { return "Текст" }
        .tcl { return "Скрипт Tcl" }
        .sh { return "Скрипт" }
        .png - .jpg - .jpeg - .gif - .webp { return "Изображение" }
        .exe { return "Программа EXE" }
        .conf - .cfg { return "Настройки" }
        default {
            if {$ext eq ""} { return "Файл" }
            return [string toupper [string range $ext 1 end]]
        }
    }
}
proc filesSizeText {n dir} {
    if {$dir} { return "" }
    if {$n < 1024} { return "$n Б" }
    if {$n < 1048576} { return [format "%.1f КБ" [expr {$n / 1024.0}]] }
    if {$n < 1073741824} { return [format "%.1f МБ" [expr {$n / 1048576.0}]] }
    return [format "%.1f ГБ" [expr {$n / 1073741824.0}]]
}
proc filesWhen {t} {
    if {$t <= 0} { return "" }
    return [clock format $t -format "%d.%m.%Y %H:%M"]
}
proc filesPlural {n} {
    set a [expr {$n % 100}]
    set b [expr {$n % 10}]
    if {$a >= 11 && $a <= 14} { return "элементов" }
    if {$b == 1} { return "элемент" }
    if {$b >= 2 && $b <= 4} { return "элемента" }
    return "элементов"
}
proc filesCaption {path} {
    if {$path eq "/" || $path eq ""} { return "Этот компьютер" }
    if {$path eq "/root"} { return "Домашняя папка" }
    return [file tail $path]
}
proc filesFit {text maxw} {
    if {$maxw < 12} { return $text }
    if {[font measure small $text] <= $maxw} { return $text }
    set t $text
    while {[string length $t] > 1 && [font measure small "$t..."] > $maxw} {
        set t [string range $t 0 end-1]
    }
    return "$t..."
}
proc filesSortMark {col title} {
    if {![info exists ::filesSort] || $::filesSort ne $col} { return $title }
    if {$::filesSortDir < 0} { return "$title  ▼" }
    return "$title  ▲"
}
proc filesGeomCols {w} {
    set sw 88
    set tw 130
    set dw 160
    set nw [expr {$w - $sw - $tw - $dw - 12}]
    if {$nw < 100} { set nw 100 }
    set x0 8
    set x1 [expr {$x0 + $nw}]
    set x2 [expr {$x1 + $dw}]
    set x3 [expr {$x2 + $tw}]
    return [list $x0 $nw $x1 $dw $x2 $tw $x3 $sw]
}
proc filesChrome {} {
    set on 0
    if {[info exists ::filesSel] && $::filesSel ne "" && [file exists $::filesSel]} { set on 1 }
    filesToolState del $on
    filesToolState ren $on
    filesToolState copy $on
    filesToolState cut $on
    set paste 0
    if {[info exists ::filesClip] && $::filesClip ne "" && [file exists $::filesClip]} { set paste 1 }
    filesToolState paste $paste
    filesArrows
    if {[info exists ::filesPath] && [winfo exists .wfiles.in.bar.h]} {
        .wfiles.in.bar.h configure -text [filesCaption $::filesPath]
    }
}
proc filesToolState {name on} {
    set f .wfiles.in.b.ribbon.tools.$name
    if {![winfo exists $f.t]} return
    if {$on} { $f.t configure -fg #1a1a1a } else { $f.t configure -fg #b0b0b0 }
}
proc filesArrows {} {
    set back 0
    set fwd 0
    if {[info exists ::filesI]} {
        if {$::filesI > 0} { set back 1 }
        if {$::filesI < [llength $::filesHist] - 1} { set fwd 1 }
    }
    filesArrowPaint .wfiles.in.b.nav.back $back
    filesArrowPaint .wfiles.in.b.nav.fwd $fwd
    set up 0
    if {[info exists ::filesPath] && $::filesPath ne "/"} { set up 1 }
    filesArrowPaint .wfiles.in.b.nav.up $up
}
proc filesArrowPaint {w on} {
    if {![winfo exists $w]} return
    if {$on} { $w configure -fg #1a1a1a } else { $w configure -fg #c8c8c8 }
}
proc filesRenderNav {} {
    set c .wfiles.in.b.body.side.c
    if {![winfo exists $c]} return
    $c delete all
    set ::filesNavN 0
    set w [winfo width $c]
    if {$w < 40} { set w 220 }
    set y 10
    set y [filesNavSection $c $w $y "Быстрый доступ"]
    set y [filesNavItem $c $w $y /root "Домашняя папка"]
    set y [filesNavItem $c $w $y /root/Desktop "Рабочий стол"]
    set y [filesNavItem $c $w $y trash: "Корзина"]
    set y [filesNavItem $c $w $y /tmp "Временные файлы"]
    set y [filesNavSection $c $w $y "Этот компьютер"]
    set y [filesNavItem $c $w $y pc: "Мой ПК"]
    set y [filesNavItem $c $w $y / "Корень"]
    set y [filesNavItem $c $w $y /root "Домашняя"]
    set y [filesNavItem $c $w $y /etc "Настройки"]
    set y [filesNavItem $c $w $y /usr "Программы"]
    set subs {}
    if {[info exists ::filesPath] && [file isdirectory $::filesPath]} {
        foreach f [lsort [glob -nocomplain -directory $::filesPath *]] {
            if {![file isdirectory $f]} continue
            set base [file tail $f]
            if {[string match .* $base]} continue
            lappend subs $f
            if {[llength $subs] >= 24} break
        }
    }
    if {[llength $subs] > 0} {
        set y [filesNavSection $c $w $y "Папки"]
        foreach f $subs {
            set y [filesNavItem $c $w $y $f [file tail $f]]
        }
    }
    $c configure -scrollregion [list 0 0 $w [expr {$y + 8}]]
}
proc filesNavSection {c w y title} {
    $c create text 14 $y -anchor w -text $title -fill #6a6a6a -font tiny
    return [expr {$y + 22}]
}
proc filesNavItem {c w y path title} {
    set bg #f5f6f7
    if {[info exists ::filesPath] && $path eq $::filesPath} { set bg #cce8ff }
    set tag nav[incr ::filesNavN]
    $c create rectangle 4 [expr {$y - 2}] [expr {$w - 4}] [expr {$y + 22}] -fill $bg -outline $bg -tags $tag
    $c create text 16 [expr {$y + 10}] -anchor w -text [filesFit $title [expr {$w - 28}]] \
        -fill #1a1a1a -font small -tags $tag
    $c bind $tag <Button-1> [list after idle [list filesGo $path]]
    return [expr {$y + 28}]
}
proc filesCrumbList {path} {
    set out [list [list "Этот компьютер" "pc:"]]
    if {$path eq "/"} { return $out }
    set acc ""
    foreach p [file split $path] {
        if {$p eq "/" || $p eq ""} continue
        if {$acc eq ""} { set acc "/$p" } else { set acc "$acc/$p" }
        if {$acc eq "/root"} {
            lappend out [list "Домашняя папка" $acc]
        } else {
            lappend out [list $p $acc]
        }
    }
    return $out
}
proc filesRenderCrumbs {} {
    set a .wfiles.in.b.nav.addr
    if {![winfo exists $a]} return
    if {[info exists ::filesEditing] && $::filesEditing} return
    if {[winfo exists $a.e] && [winfo ismapped $a.e]} { pack forget $a.e }
    if {[winfo exists $a.crumbs]} { destroy $a.crumbs }
    frame $a.crumbs -bg #ffffff
    pack $a.crumbs -side left -fill y
    set i 0
    foreach part [filesCrumbList $::filesPath] {
        lassign $part title path
        if {$i > 0} {
            label $a.crumbs.s$i -text ">" -bg #ffffff -fg #888888 -font small
            pack $a.crumbs.s$i -side left
        }
        label $a.crumbs.p$i -text $title -bg #ffffff -fg #1a1a1a -font small -padx 6 -pady 4 -cursor hand2
        pack $a.crumbs.p$i -side left
        bind $a.crumbs.p$i <Button-1> [list after idle [list filesGo $path]]
        bind $a.crumbs.p$i <Enter> [list $a.crumbs.p$i configure -bg #e5f3ff]
        bind $a.crumbs.p$i <Leave> [list $a.crumbs.p$i configure -bg #ffffff]
        incr i
    }
}
proc filesAddrEdit {} {
    set a .wfiles.in.b.nav.addr
    if {![winfo exists $a.e]} return
    if {[info exists ::filesEditing] && $::filesEditing} return
    set ::filesEditing 1
    if {[winfo exists $a.crumbs]} { pack forget $a.crumbs }
    pack $a.e -fill both -expand 1 -padx 8 -pady 2
    $a.e delete 0 end
    $a.e insert 0 $::filesPath
    focus $a.e
    $a.e icursor end
}
proc filesAddrCancel {} {
    set ::filesEditing 0
    filesRenderCrumbs
}
proc filesAddrGo {} {
    set e .wfiles.in.b.nav.addr.e
    set p [string trim [$e get]]
    set ::filesEditing 0
    if {$p eq ""} { filesRenderCrumbs; return }
    if {![string match /* $p]} { set p [file join $::filesPath $p] }
    set p [file normalize $p]
    if {![file isdirectory $p]} {
        filesRenderCrumbs
        set ::filesNote "Нет такой папки"
        filesRenderStatus
        return
    }
    filesGo $p
}
proc filesSearch {} {
    set e .wfiles.in.b.nav.q.e
    if {![winfo exists $e]} return
    set ::filesFilter [$e get]
    filesApplyFilter
    filesRenderList
    filesRenderStatus
}
proc filesHeader {} {
    set h .wfiles.in.b.body.main.head
    set c .wfiles.in.b.body.main.c
    if {![winfo exists $h]} return
    set w [winfo width $c]
    if {$w < 80} { set w [winfo width $h] }
    if {$w < 80} return
    lassign [filesGeomCols $w] x0 nw x1 dw x2 tw x3 sw
    $h.name configure -text [filesSortMark name "Имя"]
    $h.date configure -text [filesSortMark date "Дата изменения"]
    $h.type configure -text [filesSortMark type "Тип"]
    $h.size configure -text [filesSortMark size "Размер"]
    place $h.name -x [expr {$x0 + 24}] -y 0 -width [expr {$nw - 24}] -relheight 1
    place $h.date -x $x1 -y 0 -width $dw -relheight 1
    place $h.type -x $x2 -y 0 -width $tw -relheight 1
    place $h.size -x $x3 -y 0 -width $sw -relheight 1
}
proc filesLayout {} {
    if {[info exists ::filesLayoutBusy] && $::filesLayoutBusy} {
        set ::filesLayoutAgain 1
        return
    }
    set c .wfiles.in.b.body.main.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} {
        if {![info exists ::filesLayN]} { set ::filesLayN 0 }
        incr ::filesLayN
        if {$::filesLayN < 20} { after 80 filesLayout }
        return
    }
    set ::filesLayoutBusy 1
    set ::filesLayN 0
    set changed [expr {![info exists ::filesColW] || $::filesColW != $w}]
    set ::filesColW $w
    if {$changed} { filesHeader }
    if {$changed || ([info exists ::filesNeedList] && $::filesNeedList)} {
        set ::filesNeedList 0
        filesRenderList
    }
    set ::filesLayoutBusy 0
    if {[info exists ::filesLayoutAgain] && $::filesLayoutAgain} {
        set ::filesLayoutAgain 0
        filesLayout
    }
}
proc filesRenderList {} {
    set c .wfiles.in.b.body.main.c
    if {![winfo exists $c]} return
    if {![info exists ::filesRows]} { set ::filesRows {} }
    set top 0
    if {[info exists ::filesResetScroll] && $::filesResetScroll} {
        set ::filesResetScroll 0
    } else {
        set top [lindex [$c yview] 0]
    }
    $c delete all
    set ::filesHoverRow -1
    set w [winfo width $c]
    if {$w < 80} { set w 700 }
    lassign [filesGeomCols $w] x0 nw x1 dw x2 tw x3 sw
    if {[llength $::filesRows] == 0} {
        set msg "Эта папка пуста"
        if {[info exists ::filesFilter] && $::filesFilter ne ""} { set msg "Ничего не найдено" }
        if {[info exists ::filesDenied] && $::filesDenied} { set msg "Нет доступа к этой папке" }
        $c create text 20 28 -anchor w -text $msg -fill #8a8a8a -font small
        $c configure -scrollregion [list 0 0 $w 60]
        return
    }
    set y 0
    set i 0
    foreach row $::filesRows {
        lassign $row name path isdir mtime size kind
        set bg #ffffff
        if {$path eq $::filesSel} { set bg #cce8ff }
        $c create rectangle 0 $y $w [expr {$y + 32}] -fill $bg -outline $bg -tags [list r$i bg$i]
        set icon file
        if {$isdir} { set icon folder }
        filesRowIcon $c [expr {$x0 + 4}] [expr {$y + 8}] $icon r$i
        set fg #1a1a1a
        if {[info exists ::filesClipOp] && $::filesClipOp eq "cut" && $::filesClip eq $path} { set fg #9a9a9a }
        $c create text [expr {$x0 + 28}] [expr {$y + 16}] -anchor w \
            -text [filesFit $name [expr {$nw - 36}]] -fill $fg -font small -tags r$i
        $c create text $x1 [expr {$y + 16}] -anchor w -text [filesWhen $mtime] -fill #444444 -font small -tags r$i
        $c create text $x2 [expr {$y + 16}] -anchor w -text [filesFit $kind [expr {$tw - 8}]] -fill #444444 -font small -tags r$i
        $c create text [expr {$x3 + $sw - 10}] [expr {$y + 16}] -anchor e \
            -text [filesSizeText $size $isdir] -fill #444444 -font small -tags r$i
        $c bind r$i <Button-1> [list filesSelect $i]
        $c bind r$i <Double-Button-1> [list after idle [list filesOpenPath $path]]
        set y [expr {$y + 32}]
        incr i
    }
    $c configure -scrollregion [list 0 0 $w $y]
    $c yview moveto $top
}
proc filesRowIcon {c x y kind tag} {
    if {$kind eq "folder"} {
        $c create polygon \
            $x [expr {$y + 4}] \
            [expr {$x + 7}] [expr {$y + 4}] \
            [expr {$x + 9}] [expr {$y + 6}] \
            [expr {$x + 16}] [expr {$y + 6}] \
            [expr {$x + 16}] [expr {$y + 15}] \
            $x [expr {$y + 15}] \
            -fill #ffc83d -outline #e0a000 -tags $tag
    } else {
        $c create polygon \
            [expr {$x + 3}] $y \
            [expr {$x + 11}] $y \
            [expr {$x + 14}] [expr {$y + 3}] \
            [expr {$x + 14}] [expr {$y + 15}] \
            [expr {$x + 3}] [expr {$y + 15}] \
            -fill #ffffff -outline #6e6e6e -tags $tag
        $c create line \
            [expr {$x + 11}] $y \
            [expr {$x + 11}] [expr {$y + 3}] \
            [expr {$x + 14}] [expr {$y + 3}] \
            -fill #6e6e6e -tags $tag
    }
}
proc filesRenderStatus {} {
    if {![info exists ::filesRows]} { set ::filesRows {} }
    set n [llength $::filesRows]
    set left "$n [filesPlural $n]"
    if {[info exists ::filesDenied] && $::filesDenied} { set left "Нет доступа" }
    set right ""
    if {[info exists ::filesNote] && $::filesNote ne ""} {
        set right $::filesNote
    } elseif {[info exists ::filesSel] && $::filesSel ne "" && [file exists $::filesSel]} {
        set right [file tail $::filesSel]
        if {[file isdirectory $::filesSel]} {
            append right " — папка"
        } else {
            set sz 0
            catch { set sz [file size $::filesSel] }
            append right " — [filesSizeText $sz 0]"
        }
    }
    if {[winfo exists .wfiles.in.b.stat.n]} {
        .wfiles.in.b.stat.n configure -text $left
        .wfiles.in.b.stat.s configure -text $right
    }
}
proc filesSelect {i} {
    set row [lindex $::filesRows $i]
    if {$row eq ""} return
    set path [lindex $row 1]
    set ::filesSel $path
    set c .wfiles.in.b.body.main.c
    set n [llength $::filesRows]
    for {set k 0} {$k < $n} {incr k} {
        set p [lindex [lindex $::filesRows $k] 1]
        set color #ffffff
        if {$p eq $path} { set color #cce8ff }
        catch { $c itemconfigure bg$k -fill $color -outline $color }
    }
    filesChrome
    filesRenderStatus
    focus $c
}
proc filesActivate {i} {
    set row [lindex $::filesRows $i]
    if {$row eq ""} return
    filesOpenPath [lindex $row 1]
}
proc filesActivateSel {} {
    if {![info exists ::filesSel]} return
    filesOpenPath $::filesSel
}
proc filesOpenPath {path} {
    if {$path eq ""} return
    if {[file isdirectory $path]} {
        filesGo $path
    } else {
        filesOpenFile $path
    }
}
proc filesOpenFile {path} {
    set t ""
    catch { set t [file type $path] }
    if {$t ne "file"} {
        set ::filesNote "Это не обычный файл"
        filesRenderStatus
        return
    }
    openByType $path
}
proc filesBackgroundClick {x y} {
    set c .wfiles.in.b.body.main.c
    focus $c
    set cx [$c canvasx $x]
    set cy [$c canvasy $y]
    foreach id [$c find overlapping $cx $cy $cx $cy] {
        foreach t [$c gettags $id] {
            if {[regexp {^r([0-9]+)$} $t]} { return }
        }
    }
    set ::filesSel ""
    set n [llength $::filesRows]
    for {set k 0} {$k < $n} {incr k} {
        catch { $c itemconfigure bg$k -fill #ffffff -outline #ffffff }
    }
    filesChrome
    filesRenderStatus
}
proc filesMotion {x y} {
    set c .wfiles.in.b.body.main.c
    if {![winfo exists $c] || ![info exists ::filesRows]} return
    set cy [$c canvasy $y]
    set i [expr {int($cy / 32.0)}]
    if {[info exists ::filesHoverRow] && $i == $::filesHoverRow} return
    if {[info exists ::filesHoverRow] && $::filesHoverRow >= 0} { filesHover $::filesHoverRow 0 }
    set ::filesHoverRow $i
    if {$i >= 0 && $i < [llength $::filesRows]} {
        filesHover $i 1
    } else {
        set ::filesHoverRow -1
    }
}
proc filesLeave {} {
    if {[info exists ::filesHoverRow] && $::filesHoverRow >= 0} { filesHover $::filesHoverRow 0 }
    set ::filesHoverRow -1
}
proc filesHover {i on} {
    set c .wfiles.in.b.body.main.c
    if {![winfo exists $c]} return
    if {![info exists ::filesRows] || $i < 0 || $i >= [llength $::filesRows]} return
    set path [lindex [lindex $::filesRows $i] 1]
    if {$path eq $::filesSel} return
    set color #ffffff
    if {$on} { set color #e5f3ff }
    catch { $c itemconfigure bg$i -fill $color -outline $color }
}
proc filesMove {dir} {
    if {![info exists ::filesRows]} return
    set n [llength $::filesRows]
    if {$n == 0} return
    set i -1
    set k 0
    foreach row $::filesRows {
        if {[lindex $row 1] eq $::filesSel} { set i $k }
        incr k
    }
    if {$i < 0} { set i 0 } else { incr i $dir }
    if {$i < 0} { set i 0 }
    if {$i >= $n} { set i [expr {$n - 1}] }
    filesSelect $i
    filesReveal $i
}
proc filesReveal {i} {
    set c .wfiles.in.b.body.main.c
    if {![winfo exists $c]} return
    set total [expr {[llength $::filesRows] * 32}]
    if {$total <= 0} return
    set y [expr {$i * 32}]
    set h [winfo height $c]
    if {$h < 32} { set h 32 }
    lassign [$c yview] a b
    set top [expr {$a * $total}]
    set bot [expr {$b * $total}]
    if {$y < $top} {
        $c yview moveto [expr {double($y) / $total}]
    } elseif {$y + 32 > $bot} {
        set ny [expr {$y + 32 - $h}]
        if {$ny < 0} { set ny 0 }
        $c yview moveto [expr {double($ny) / $total}]
    }
}
proc filesSortBy {col} {
    if {$::filesSort eq $col} {
        set ::filesSortDir [expr {-$::filesSortDir}]
    } else {
        set ::filesSort $col
        set ::filesSortDir 1
    }
    filesApplyFilter
    filesHeader
    filesRenderList
}
proc filesProtected {path} {
    foreach p {/ /root /usr /bin /sbin /lib /etc /dev /proc /sys /boot /init} {
        if {$path eq $p} { return 1 }
    }
    return 0
}
proc filesGoodName {name} {
    if {$name eq "" || $name eq "." || $name eq ".."} { return 0 }
    if {[string first / $name] >= 0} { return 0 }
    return 1
}
proc filesPrompt {title initial command} {
    dialog $title
    entry .ask.in.e -bg $::CARD -fg $::WHITE -insertbackground $::ACCENT -font ui \
        -highlightthickness 1 -highlightbackground $::LINE -highlightcolor $::ACCENT
    pack .ask.in.e -fill x -padx 22 -ipady 6
    .ask.in.e insert 0 $initial
    .ask.in.e selection range 0 end
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 16
    button .ask.in.bt.ok -text "ОК" -command [list filesPromptGo $command] -bg $::ACCENT -fg $::INK -font ui -padx 14 -pady 6
    button .ask.in.bt.no -text "Отмена" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 14 -pady 6
    pack .ask.in.bt.no .ask.in.bt.ok -side right -padx 10
    focus .ask.in.e
    bind .ask.in.e <Return> [list filesPromptGo $command]
    bind .ask.in.e <Escape> { destroy .ask }
}
proc filesPromptGo {command} {
    set name ""
    if {[winfo exists .ask.in.e]} { set name [string trim [.ask.in.e get]] }
    destroy .ask
    if {$name eq ""} return
    $command $name
}
proc filesNewDir {} { filesPrompt "Новая папка" "Новая папка" filesDoNewDir }
proc filesDoNewDir {name} {
    if {![filesGoodName $name]} return
    set dest [file join $::filesPath $name]
    if {[file exists $dest]} {
        set ::filesNote "Уже существует"
        filesRenderStatus
        return
    }
    file mkdir $dest
    set ::filesSel $dest
    filesRender
}
proc filesDelete {} {
    if {![info exists ::filesSel] || $::filesSel eq "" || ![file exists $::filesSel]} return
    if {[filesProtected $::filesSel]} {
        set ::filesNote "Эту папку нельзя удалить"
        filesRenderStatus
        return
    }
    if {[trashInside $::filesSel]} {
        dialog "Удалить [file tail $::filesSel] навсегда?"
        set ok "Удалить"
    } else {
        dialog "Переместить [file tail $::filesSel] в корзину?"
        set ok "В корзину"
    }
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 8
    button .ask.in.bt.ok -text $ok -command filesDoDelete -bg $::DANGER -fg #ffffff -font ui -padx 12 -pady 6
    button .ask.in.bt.no -text "Отмена" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
    pack .ask.in.bt.no .ask.in.bt.ok -side right -padx 16
}
proc filesDoDelete {} {
    set path $::filesSel
    catch { destroy .ask }
    if {$path eq "" || [filesProtected $path]} return
    if {[trashInside $path]} {
        catch { file delete -force $path }
        trashForget [file tail $path]
    } else {
        trashPut $path
    }
    if {[info exists ::filesClip] && $::filesClip eq $path} {
        set ::filesClip ""
        set ::filesClipOp ""
    }
    set ::filesSel ""
    filesRender
    paintDeskIcons
    if {[winfo exists .wtrash]} { trashRender }
}
proc filesRename {} {
    if {![info exists ::filesSel] || $::filesSel eq "" || ![file exists $::filesSel]} return
    if {[filesProtected $::filesSel]} return
    filesPrompt "Переименовать" [file tail $::filesSel] filesDoRename
}
proc filesDoRename {name} {
    if {![filesGoodName $name]} return
    set src $::filesSel
    if {[filesProtected $src]} return
    set dest [file join [file dirname $src] $name]
    if {$dest eq $src} return
    if {[file exists $dest]} {
        set ::filesNote "Уже существует"
        filesRenderStatus
        return
    }
    if {[catch {file rename $src $dest}]} {
        set ::filesNote "Не удалось переименовать"
        filesRenderStatus
        return
    }
    if {[info exists ::filesClip] && $::filesClip eq $src} { set ::filesClip $dest }
    set ::filesSel $dest
    filesRender
}
proc filesCopy {} {
    if {![info exists ::filesSel] || $::filesSel eq "" || ![file exists $::filesSel]} return
    set ::filesClip $::filesSel
    set ::filesClipOp copy
    filesChrome
    filesRenderList
}
proc filesCut {} {
    if {![info exists ::filesSel] || $::filesSel eq "" || ![file exists $::filesSel]} return
    if {[filesProtected $::filesSel]} return
    set ::filesClip $::filesSel
    set ::filesClipOp cut
    filesChrome
    filesRenderList
}
proc filesUnique {path} {
    if {![file exists $path]} { return $path }
    set dir [file dirname $path]
    set tail [file tail $path]
    set ext [file extension $tail]
    set base [file rootname $tail]
    set i 2
    while {[file exists [file join $dir "$base ($i)$ext"]]} {
        incr i
        if {$i > 99} break
    }
    return [file join $dir "$base ($i)$ext"]
}
proc filesPaste {} {
    if {![info exists ::filesClip] || $::filesClip eq "" || ![file exists $::filesClip]} return
    set src [file normalize $::filesClip]
    set dir [file normalize $::filesPath]
    if {$src eq $dir} return
    if {[string match "$src/*" $dir]} {
        set ::filesNote "Нельзя вставить папку в саму себя"
        filesRenderStatus
        return
    }
    set dest [filesUnique [file join $dir [file tail $src]]]
    if {$::filesClipOp eq "cut"} {
        if {[catch {file rename $src $dest}]} {
            set ::filesNote "Не удалось переместить"
            filesRenderStatus
            return
        }
        set ::filesClip ""
        set ::filesClipOp ""
    } else {
        if {[catch {file copy $src $dest}]} {
            set ::filesNote "Не удалось скопировать"
            filesRenderStatus
            return
        }
    }
    set ::filesSel $dest
    set ::filesNote ""
    filesRender
}
proc filesProps {} {
    set path ""
    if {[info exists ::filesSel]} { set path $::filesSel }
    if {$path eq "" || ![file exists $path]} { set path $::filesPath }
    if {![file exists $path]} return
    set isdir [file isdirectory $path]
    set when ""
    catch { set when [filesWhen [file mtime $path]] }
    set kind [filesKind $path $isdir]
    if {$isdir} {
        set size "Папка"
    } else {
        set n 0
        catch { set n [file size $path] }
        set size [filesSizeText $n 0]
    }
    dialog "Свойства"
    wm geometry .ask 480x230+[expr {($::SW - 480) / 2}]+[expr {($::SH - 230) / 2}]
    label .ask.in.d -text "$path\n$kind\n$when\n$size" -bg $::MICA -fg $::WHITE -font small -anchor w -justify left
    pack .ask.in.d -anchor w -padx 22
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 12
    button .ask.in.bt.no -text "Закрыть" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
    pack .ask.in.bt.no -side right -padx 16
}
proc filesMenu {rx ry x y} {
    set c .wfiles.in.b.body.main.c
    set cx [$c canvasx $x]
    set cy [$c canvasy $y]
    set hit -1
    foreach id [$c find overlapping $cx $cy $cx $cy] {
        foreach t [$c gettags $id] {
            if {[regexp {^r([0-9]+)$} $t -> idx]} { set hit $idx }
        }
    }
    if {$hit >= 0} { filesSelect $hit }
    filesMenuHide
    toplevel .fmenu
    wm overrideredirect .fmenu 1
    .fmenu configure -bg #c8c8c8
    frame .fmenu.f -bg #ffffff
    pack .fmenu.f -padx 1 -pady 1
    if {$hit >= 0} {
        filesMenuItem "Открыть" filesActivateSel
        filesMenuItem "Вырезать" filesCut
        filesMenuItem "Копировать" filesCopy
        filesMenuItem "Переименовать" filesRename
        filesMenuItem "Удалить" filesDelete
        filesMenuItem "Свойства" filesProps
    } else {
        filesMenuItem "Новая папка" filesNewDir
        filesMenuItem "Вставить" filesPaste
        filesMenuItem "Обновить" filesRefresh
    }
    update idletasks
    set mw [winfo reqwidth .fmenu]
    set mh [winfo reqheight .fmenu]
    if {$rx + $mw > $::SW} { set rx [expr {$::SW - $mw - 4}] }
    if {$ry + $mh > $::SH - $::BARH} { set ry [expr {$::SH - $::BARH - $mh - 4}] }
    if {$rx < 0} { set rx 0 }
    if {$ry < 0} { set ry 0 }
    wm geometry .fmenu +$rx+$ry
    raise .fmenu
}
proc filesMenuItem {text cmd} {
    set n [llength [winfo children .fmenu.f]]
    label .fmenu.f.i$n -text $text -bg #ffffff -fg #1a1a1a -font small -anchor w -padx 18 -pady 6 -cursor hand2
    pack .fmenu.f.i$n -fill x
    bind .fmenu.f.i$n <Enter> [list .fmenu.f.i$n configure -bg #cce8ff]
    bind .fmenu.f.i$n <Leave> [list .fmenu.f.i$n configure -bg #ffffff]
    bind .fmenu.f.i$n <Button-1> [list filesMenuDo $cmd]
}
proc filesMenuDo {cmd} {
    after idle [list filesMenuRun $cmd]
}
proc filesMenuRun {cmd} {
    filesMenuHide
    $cmd
}
proc filesMenuHide {} { catch { destroy .fmenu } }

proc trashDir {} {
    set d /root/.Trash
    file mkdir $d
    return $d
}
proc trashInside {path} {
    if {$path eq ""} { return 0 }
    set root [file normalize [trashDir]]
    set path [file normalize $path]
    if {$path eq $root} { return 1 }
    if {[string match $root/* $path]} { return 1 }
    return 0
}
proc trashLoadMeta {} {
    array unset ::trashOrig
    array set ::trashOrig {}
    set p [file join [trashDir] .meta]
    if {![file exists $p]} return
    set fh [open $p r]
    while {[gets $fh line] >= 0} {
        if {[regexp {^([^\t]+)\t(.*)$} $line -> name orig]} {
            set ::trashOrig($name) $orig
        }
    }
    close $fh
}
proc trashSaveMeta {} {
    set fh [open [file join [trashDir] .meta] w]
    foreach {name orig} [array get ::trashOrig] {
        puts $fh "$name\t$orig"
    }
    close $fh
}
proc trashForget {name} {
    trashLoadMeta
    unset -nocomplain ::trashOrig($name)
    trashSaveMeta
}
proc trashPut {path} {
    if {![file exists $path] || [filesProtected $path] || [trashInside $path]} { return 0 }
    set dir [trashDir]
    set base [file tail $path]
    set dest [file join $dir $base]
    set i 2
    while {[file exists $dest]} {
        set dest [file join $dir "$base ($i)"]
        incr i
        if {$i > 99} { break }
    }
    if {[catch {file rename $path $dest}]} { return 0 }
    trashLoadMeta
    set ::trashOrig([file tail $dest]) [file normalize $path]
    trashSaveMeta
    return 1
}
proc pcMountTitle {mount} {
    if {$mount eq "/"} { return "Система" }
    if {$mount eq "/root"} { return "Домашняя" }
    if {$mount eq "/root/Desktop"} { return "Рабочий стол" }
    return $mount
}
proc pcDrives {} {
    set out {}
    set text [sh "df -P -k 2>/dev/null"]
    foreach line [lrange [split $text \n] 1 end] {
        if {$line eq ""} continue
        set parts [regexp -inline -all {\S+} $line]
        if {[llength $parts] < 6} continue
        set mount [lindex $parts end]
        set blocks [lindex $parts 1]
        set used [lindex $parts 2]
        set avail [lindex $parts 3]
        if {![string is integer -strict $blocks]} continue
        if {![string is integer -strict $used]} continue
        if {![string is integer -strict $avail]} continue
        if {$mount eq "/proc" || $mount eq "/sys" || $mount eq "/dev" || $mount eq "/tmp"} continue
        if {[string match /dev/* $mount] || [string match /proc/* $mount] || [string match /sys/* $mount] || [string match /run/* $mount]} continue
        lappend out [list $mount [lindex $parts 0] [expr {$blocks * 1024}] [expr {$used * 1024}] [expr {$avail * 1024}]]
    }
    if {[llength $out] == 0 && [file isdirectory /]} {
        lappend out [list / rootfs 0 0 0]
    }
    return $out
}
proc pcNets {} {
    set out {}
    set text [sh "ip -4 -o addr show scope global 2>/dev/null"]
    foreach line [split $text \n] {
        if {[regexp {^(\S+)\s+inet\s+([0-9.]+)} $line -> dev addr]} {
            lappend out [list $dev $addr]
        }
    }
    return $out
}
proc openPC {} {
    set w [newWindow pc "Мой ПК" 980 640]
    set b $w.in.b
    if {![winfo exists $b.nav]} {
        $b configure -bg #ffffff
        frame $b.nav -bg #f5f6f7 -height 42
        pack $b.nav -side top -fill x
        pack propagate $b.nav 0
        label $b.nav.addr -text "  Этот компьютер" -bg #ffffff -fg #1a1a1a -font small -anchor w
        pack $b.nav.addr -side left -fill both -expand 1 -padx 8 -pady 7
        label $b.nav.r -text "Обновить" -bg #f5f6f7 -fg #1a1a1a -font small -padx 12 -cursor hand2
        pack $b.nav.r -side right -padx 8 -pady 6
        bind $b.nav.r <Button-1> { set ::pcW -1; pcRender }
        bind $b.nav.r <Enter> [list $b.nav.r configure -bg #e5f1fb]
        bind $b.nav.r <Leave> [list $b.nav.r configure -bg #f5f6f7]
        frame $b.side -bg #f5f6f7 -width 220
        pack $b.side -side left -fill y
        pack propagate $b.side 0
        frame $b.sep -bg #e5e5e5 -width 1
        pack $b.sep -side left -fill y
        pack propagate $b.sep 0
        canvas $b.c -bg #ffffff -highlightthickness 0 -bd 0
        pack $b.c -side left -fill both -expand 1
        bind $b.c <Button-4> {%W yview scroll -3 units}
        bind $b.c <Button-5> {%W yview scroll 3 units}
        bind $b.c <Configure> { if {![info exists ::pcW] || $::pcW != [winfo width %W]} pcRender }
    }
    set ::pcW -1
    pcRender
}
proc pcSideGo {path} {
    if {$path eq "pc:"} { set ::pcW -1; pcRender; return }
    if {$path eq "trash:"} { openTrash; return }
    openFiles $path
}
proc pcFillSide {} {
    set s .wpc.in.b.side
    if {![winfo exists $s]} return
    foreach c [winfo children $s] { destroy $c }
    label $s.h -text "Этот компьютер" -bg #f5f6f7 -fg #6a6a6a -font tiny -anchor w
    pack $s.h -fill x -padx 16 -pady {12 4}
    set n 0
    pcSideLink $s $n pc: "Этот компьютер" 1
    incr n
    foreach d [pcDrives] {
        set mount [lindex $d 0]
        pcSideLink $s $n $mount [pcMountTitle $mount] 0
        incr n
    }
    pcSideLink $s $n trash: "Корзина" 0
    incr n
    pcSideLink $s $n /root/Desktop "Рабочий стол" 0
}
proc pcSideLink {parent n path title on} {
    set bg #f5f6f7
    if {$on} { set bg #cce8ff }
    label $parent.i$n -text $title -bg $bg -fg #1a1a1a -font small -anchor w -padx 16 -pady 6 -cursor hand2
    pack $parent.i$n -fill x -padx 6 -pady 1
    bind $parent.i$n <Button-1> [list pcSideGo $path]
    if {!$on} {
        bind $parent.i$n <Enter> [list $parent.i$n configure -bg #e5f3ff]
        bind $parent.i$n <Leave> [list $parent.i$n configure -bg #f5f6f7]
    }
}
proc pcCard {c x y w h mount total used avail} {
    set tag pc[incr ::pcCard]
    set bg ${tag}bg
    $c create rectangle $x $y [expr {$x + $w}] [expr {$y + $h}] -fill #f8f8f8 -outline #e5e5e5 -width 1 -tags [list $tag $bg]
    $c create rectangle [expr {$x + 14}] [expr {$y + 18}] [expr {$x + 42}] [expr {$y + 40}] -fill #0078d7 -outline {} -tags $tag
    $c create rectangle [expr {$x + 18}] [expr {$y + 22}] [expr {$x + 38}] [expr {$y + 36}] -fill #d6ecff -outline {} -tags $tag
    $c create rectangle [expr {$x + 22}] [expr {$y + 40}] [expr {$x + 34}] [expr {$y + 44}] -fill #0078d7 -outline {} -tags $tag
    $c create text [expr {$x + 54}] [expr {$y + 18}] -anchor w -text [pcMountTitle $mount] -fill #1a1a1a -font small -tags $tag
    $c create text [expr {$x + 54}] [expr {$y + 36}] -anchor w -text $mount -fill #777777 -font tiny -tags $tag
    set bw [expr {$w - 68}]
    set bx [expr {$x + 54}]
    set by [expr {$y + 50}]
    $c create rectangle $bx $by [expr {$bx + $bw}] [expr {$by + 8}] -fill #e6e6e6 -outline {} -tags $tag
    if {$total > 0} {
        set fw [expr {int($bw * ($used / double($total)))}]
        if {$fw < 0} { set fw 0 }
        if {$fw > $bw} { set fw $bw }
        set col #0078d7
        if {$used * 100 > $total * 90} { set col #e81123 }
        if {$fw > 0} {
            $c create rectangle $bx $by [expr {$bx + $fw}] [expr {$by + 8}] -fill $col -outline {} -tags $tag
        }
        set cap "[filesSizeText $avail 0] свободно из [filesSizeText $total 0]"
    } else {
        set cap "размер недоступен"
    }
    $c create text [expr {$x + 54}] [expr {$y + 72}] -anchor w -text $cap -fill #555555 -font tiny -tags $tag
    $c bind $tag <Double-Button-1> [list openFiles $mount]
    $c bind $tag <Enter> [list $c itemconfigure $bg -fill #eef6fc]
    $c bind $tag <Leave> [list $c itemconfigure $bg -fill #f8f8f8]
}
proc pcNetCard {c x y w dev addr} {
    set tag net[incr ::pcCard]
    $c create rectangle $x $y [expr {$x + $w}] [expr {$y + 78}] -fill #f8f8f8 -outline #e5e5e5 -tags $tag
    $c create oval [expr {$x + 16}] [expr {$y + 20}] [expr {$x + 40}] [expr {$y + 44}] -outline #0078d7 -width 2 -tags $tag
    $c create text [expr {$x + 54}] [expr {$y + 24}] -anchor w -text $dev -fill #1a1a1a -font small -tags $tag
    $c create text [expr {$x + 54}] [expr {$y + 46}] -anchor w -text $addr -fill #555555 -font tiny -tags $tag
}
proc pcRender {} {
    set c .wpc.in.b.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} {
        if {![info exists ::pcWait]} { set ::pcWait 0 }
        incr ::pcWait
        if {$::pcWait < 20} { after 80 pcRender }
        return
    }
    set ::pcWait 0
    if {[info exists ::pcW] && $::pcW == $w && [info exists ::pcHold] && $::pcHold} return
    set ::pcW $w
    pcFillSide
    $c delete all
    set ::pcCard 0
    $c create text 18 22 -anchor w -text "Устройства и диски" -fill #1a1a1a -font uib
    set y 46
    set x 16
    set cardw 260
    set cardh 92
    set n 0
    foreach d [pcDrives] {
        lassign $d mount fs total used avail
        if {$x + $cardw > $w - 8} {
            set x 16
            incr y [expr {$cardh + 12}]
        }
        pcCard $c $x $y $cardw $cardh $mount $total $used $avail
        incr x [expr {$cardw + 12}]
        incr n
    }
    if {$n == 0} {
        $c create text 18 [expr {$y + 8}] -anchor w -text "Диски не найдены" -fill #888888 -font small
        set y [expr {$y + 36}]
    } else {
        incr y [expr {$cardh + 24}]
    }
    set nets [pcNets]
    if {[llength $nets] > 0} {
        $c create text 18 $y -anchor w -text "Сеть" -fill #1a1a1a -font uib
        incr y 32
        set x 16
        foreach item $nets {
            lassign $item dev addr
            if {$x + $cardw > $w - 8} { set x 16; incr y 90 }
            pcNetCard $c $x $y $cardw $dev $addr
            incr x [expr {$cardw + 12}]
        }
        incr y 96
    }
    $c configure -scrollregion [list 0 0 $w [expr {$y + 12}]]
}
proc openTrash {} {
    set w [newWindow trash "Корзина" 860 540]
    set b $w.in.b
    if {![winfo exists $b.tools]} {
        $b configure -bg #ffffff
        frame $b.tools -bg #f5f6f7 -height 48
        pack $b.tools -side top -fill x
        pack propagate $b.tools 0
        label $b.tools.clear -text "Очистить корзину" -bg #f5f6f7 -fg #1a1a1a -font small -padx 14 -pady 8 -cursor hand2
        pack $b.tools.clear -side left -padx 8 -pady 8
        label $b.tools.back -text "Восстановить" -bg #f5f6f7 -fg #1a1a1a -font small -padx 14 -pady 8 -cursor hand2
        pack $b.tools.back -side left -padx 4 -pady 8
        label $b.tools.boot -text "Очищать при включении" -bg #f5f6f7 -fg #1a1a1a -font small -padx 14 -pady 8 -cursor hand2
        pack $b.tools.boot -side right -padx 8 -pady 8
        bind $b.tools.boot <Button-1> trashToggleBoot
        bind $b.tools.boot <Enter> [list $b.tools.boot configure -bg #e5f1fb]
        bind $b.tools.boot <Leave> [list trashBootPaint]
        bind $b.tools.clear <Button-1> trashAskEmpty
        bind $b.tools.back <Button-1> trashRestore
        bind $b.tools.clear <Enter> [list $b.tools.clear configure -bg #e5f1fb]
        bind $b.tools.clear <Leave> [list $b.tools.clear configure -bg #f5f6f7]
        bind $b.tools.back <Enter> [list $b.tools.back configure -bg #e5f1fb]
        bind $b.tools.back <Leave> [list $b.tools.back configure -bg #f5f6f7]
        frame $b.head -bg #ffffff -height 30
        pack $b.head -side top -fill x
        pack propagate $b.head 0
        frame $b.head.line -bg #e5e5e5 -height 1
        place $b.head.line -rely 1 -y -1 -relwidth 1 -height 1
        label $b.head.n -text "Имя" -bg #ffffff -fg #4a4a4a -font small -anchor w
        label $b.head.o -text "Откуда" -bg #ffffff -fg #4a4a4a -font small -anchor w
        label $b.head.s -text "Размер" -bg #ffffff -fg #4a4a4a -font small -anchor e
        place $b.head.n -x 36 -y 0 -relheight 1 -relwidth 0.4
        place $b.head.o -relx 0.42 -y 0 -relheight 1 -relwidth 0.38
        place $b.head.s -relx 0.8 -y 0 -relheight 1 -relwidth 0.18
        frame $b.stat -bg #f5f6f7 -height 26
        pack $b.stat -side bottom -fill x
        pack propagate $b.stat 0
        label $b.stat.n -text "" -bg #f5f6f7 -fg #1a1a1a -font small -anchor w
        place $b.stat.n -x 12 -rely 0.5 -anchor w
        canvas $b.c -bg #ffffff -highlightthickness 0 -bd 0
        pack $b.c -fill both -expand 1
        bind $b.c <Button-4> {%W yview scroll -3 units}
        bind $b.c <Button-5> {%W yview scroll 3 units}
        bind $b.c <Configure> { if {![info exists ::trashW] || $::trashW != [winfo width %W]} trashRender }
    }
    set ::trashW -1
    set ::trashSel ""
    trashBootPaint
    trashRender
}
proc trashBootPaint {} {
    set w .wtrash.in.b.tools.boot
    if {![winfo exists $w]} return
    if {[info exists ::set_trashboot] && $::set_trashboot eq "1"} {
        $w configure -bg #1a1a1a -fg #ffffff
    } else {
        $w configure -bg #f5f6f7 -fg #1a1a1a
    }
}
proc trashToggleBoot {} {
    if {![info exists ::set_trashboot] || $::set_trashboot ne "1"} {
        set ::set_trashboot 1
    } else {
        set ::set_trashboot 0
    }
    settingsPut TRASH_BOOT $::set_trashboot
    trashBootPaint
}
proc trashQuietEmpty {} {
    set n 0
    foreach f [glob -nocomplain -directory [trashDir] *] {
        catch { file delete -force $f }
        incr n
    }
    catch { close [open [file join [trashDir] .meta] w] }
    array unset ::trashOrig
    array set ::trashOrig {}
    if {$n > 0} { notify "Корзина" "Очищена при включении" }
}
proc trashAskEmpty {} {
    set n 0
    foreach f [glob -nocomplain -directory [trashDir] *] { incr n }
    if {$n == 0} return
    dialog "Очистить корзину?"
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 8
    button .ask.in.bt.ok -text "Очистить" -command trashDoEmpty -bg $::DANGER -fg #ffffff -font ui -padx 12 -pady 6
    button .ask.in.bt.no -text "Отмена" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
    pack .ask.in.bt.no .ask.in.bt.ok -side right -padx 16
}
proc trashDoEmpty {} {
    catch { destroy .ask }
    foreach f [glob -nocomplain -directory [trashDir] *] {
        catch { file delete -force $f }
    }
    catch { close [open [file join [trashDir] .meta] w] }
    array unset ::trashOrig
    array set ::trashOrig {}
    set ::trashSel ""
    trashRender
    paintDeskIcons
}
proc trashRestore {} {
    if {![info exists ::trashSel] || $::trashSel eq "" || ![file exists $::trashSel]} return
    trashLoadMeta
    set name [file tail $::trashSel]
    set orig [file join /root/Desktop $name]
    if {[info exists ::trashOrig($name)] && $::trashOrig($name) ne ""} {
        set orig $::trashOrig($name)
    }
    set parent [file dirname $orig]
    if {![file isdirectory $parent]} {
        file mkdir /root/Desktop
        set orig [file join /root/Desktop $name]
    }
    if {[file exists $orig]} { set orig [filesUnique $orig] }
    if {[catch {file rename $::trashSel $orig}]} return
    notify "Корзина" "Восстановлено: [file tail $orig]"
    trashForget $name
    set ::trashSel ""
    trashRender
    paintDeskIcons
    if {[winfo exists .wfiles]} { catch {filesRefresh} }
}
proc trashRender {} {
    set c .wtrash.in.b.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} {
        if {![info exists ::trashWait]} { set ::trashWait 0 }
        incr ::trashWait
        if {$::trashWait < 20} { after 80 trashRender }
        return
    }
    set ::trashWait 0
    set ::trashW $w
    trashLoadMeta
    $c delete all
    set files {}
    foreach f [lsort [glob -nocomplain -directory [trashDir] *]] {
        lappend files $f
    }
    if {[llength $files] == 0} {
        $c create text 24 28 -anchor w -text "Корзина пуста" -fill #8a8a8a -font small
        if {[winfo exists .wtrash.in.b.stat.n]} { .wtrash.in.b.stat.n configure -text "0 элементов" }
        $c configure -scrollregion [list 0 0 $w 60]
        return
    }
    set y 0
    set i 0
    foreach f $files {
        set name [file tail $f]
        set orig ""
        if {[info exists ::trashOrig($name)]} { set orig $::trashOrig($name) }
        set bg #ffffff
        if {[info exists ::trashSel] && $::trashSel eq $f} { set bg #cce8ff }
        set tag tr$i
        $c create rectangle 0 $y $w [expr {$y + 32}] -fill $bg -outline $bg -tags [list $tag bg$tag]
        set icon file
        if {[file isdirectory $f]} { set icon folder }
        filesRowIcon $c 10 [expr {$y + 8}] $icon $tag
        $c create text 36 [expr {$y + 16}] -anchor w -text [filesFit $name [expr {$w * 0.36}]] -fill #1a1a1a -font small -tags $tag
        $c create text [expr {int($w * 0.42)}] [expr {$y + 16}] -anchor w -text [filesFit $orig [expr {$w * 0.36}]] -fill #555555 -font small -tags $tag
        set sz 0
        set isdir [file isdirectory $f]
        if {!$isdir} { catch { set sz [file size $f] } }
        $c create text [expr {$w - 16}] [expr {$y + 16}] -anchor e -text [filesSizeText $sz $isdir] -fill #444444 -font small -tags $tag
        $c bind $tag <Button-1> [list trashSelect $f]
        $c bind $tag <Double-Button-1> [list trashOpen $f]
        incr y 32
        incr i
    }
    $c configure -scrollregion [list 0 0 $w $y]
    if {[winfo exists .wtrash.in.b.stat.n]} {
        .wtrash.in.b.stat.n configure -text "[llength $files] [filesPlural [llength $files]]"
    }
}
proc trashSelect {path} {
    set ::trashSel $path
    set ::trashW -1
    trashRender
}
proc trashOpen {path} {
    if {[file isdirectory $path]} { openFiles $path } else { openByType $path }
}
proc deskPosFile {} {
    file mkdir /root/.config/deepos
    return /root/.config/deepos/icons.pos
}
proc deskLoadPos {} {
    array unset ::iconPos
    array set ::iconPos {}
    set p [deskPosFile]
    if {![file exists $p]} return
    set fh [open $p r]
    while {[gets $fh line] >= 0} {
        if {![regexp {^([^\t]+)\t(-?[0-9]+)\t(-?[0-9]+)$} $line -> key x y]} continue
        set ::iconPos($key) [list $x $y]
    }
    close $fh
}
proc deskSaveAllPos {} {
    set fh [open [deskPosFile] w]
    if {[info exists ::deskIcons]} {
        foreach f $::deskIcons {
            if {![winfo exists $f] || ![info exists ::deskKey($f)]} continue
            puts $fh "$::deskKey($f)\t[winfo x $f]\t[winfo y $f]"
        }
    }
    close $fh
}
proc deskGrid {} {
    set rows [expr {($::SH - $::BARH - 20) / 100}]
    if {$rows < 1} { set rows 1 }
    set cols [expr {($::SW - 40) / 108}]
    if {$cols < 1} { set cols 1 }
    return [list $rows $cols]
}
proc deskXY {col r} {
    return [list [expr {18 + $col * 108}] [expr {16 + $r * 100}]]
}
proc deskCell {x y} {
    lassign [deskGrid] rows cols
    set col [expr {round(($x - 18) / 108.0)}]
    set r [expr {round(($y - 16) / 100.0)}]
    if {$col < 0} { set col 0 }
    if {$r < 0} { set r 0 }
    if {$col >= $cols} { set col [expr {$cols - 1}] }
    if {$r >= $rows} { set r [expr {$rows - 1}] }
    return [list $col $r]
}
proc deskAuto {index} {
    lassign [deskGrid] rows cols
    set col [expr {$index / $rows}]
    set r [expr {$index % $rows}]
    if {$col >= $cols} {
        set col [expr {$cols - 1}]
        set r [expr {$rows - 1}]
    }
    return [deskXY $col $r]
}
proc deskUsed {except} {
    set out {}
    if {![info exists ::deskIcons]} { return $out }
    foreach w $::deskIcons {
        if {$w eq $except || ![winfo exists $w]} continue
        lassign [deskCell [winfo x $w] [winfo y $w]] c r
        lappend out "$c,$r"
    }
    return $out
}
proc deskSnap {self x y} {
    lassign [deskGrid] rows cols
    lassign [deskCell $x $y] col r
    set used [deskUsed $self]
    if {[lsearch -exact $used "$col,$r"] < 0} { return [deskXY $col $r] }
    for {set rad 1} {$rad < 30} {incr rad} {
        for {set dc [expr {0 - $rad}]} {$dc <= $rad} {incr dc} {
            foreach dr [list [expr {0 - $rad}] $rad] {
                set c [expr {$col + $dc}]
                set rr [expr {$r + $dr}]
                if {$c < 0 || $rr < 0 || $c >= $cols || $rr >= $rows} continue
                if {[lsearch -exact $used "$c,$rr"] < 0} { return [deskXY $c $rr] }
            }
        }
        for {set dr [expr {1 - $rad}]} {$dr < $rad} {incr dr} {
            foreach dc [list [expr {0 - $rad}] $rad] {
                set c [expr {$col + $dc}]
                set rr [expr {$r + $dr}]
                if {$c < 0 || $rr < 0 || $c >= $cols || $rr >= $rows} continue
                if {[lsearch -exact $used "$c,$rr"] < 0} { return [deskXY $c $rr] }
            }
        }
    }
    return [deskXY $col $r]
}
proc paintDeskIcons {} {
    if {[info exists ::deskGrab] && $::deskGrab ne ""} return
    if {![info exists ::deskIcons]} { set ::deskIcons {} }
    foreach w $::deskIcons { catch { destroy $w } }
    set ::deskIcons {}
    array unset ::deskPath
    array unset ::deskKey
    array set ::deskPath {}
    array set ::deskKey {}
    file mkdir /root/Desktop
    trashDir
    deskLoadPos
    set items {}
    lappend items [list pc pc "Мой ПК" {openApp pc}]
    set kind trash
    if {[llength [glob -nocomplain -directory [trashDir] *]] > 0} { set kind trashfull }
    lappend items [list trash $kind "Корзина" {openApp trash}]
    foreach f [lsort [glob -nocomplain -directory /root/Desktop *]] {
        set base [file tail $f]
        if {[string match .* $base]} continue
        set ik doc
        set title [deskShort $base]
        if {[file isdirectory $f]} { set ik files }
        if {[string equal -nocase [file extension $base] .deepos]} {
            set title [deskShort [file rootname $base]]
            set ik term
            if {[string match *\ngui=1* "\n[readFile $f 500]"]} { set ik pc }
            if {$title eq "Firefox"} { set ik firefox }
            if {$title eq "Chrome"} { set ik chrome }
        }
        if {[string equal -nocase [file extension $base] .exe]} { set ik exe }
        lappend items [list [file normalize $f] $ik $title [list deskOpen $f]]
    }
    set placed {}
    set n 0
    set i 0
    foreach item $items {
        lassign $item key ik title cmd
        set xy ""
        if {[info exists ::iconPos($key)]} {
            lassign $::iconPos($key) sx sy
            lassign [deskCell $sx $sy] c r
            if {[lsearch -exact $placed "$c,$r"] < 0} { set xy [deskXY $c $r] }
        }
        if {$xy eq ""} {
            while {$n < 400} {
                set xy [deskAuto $n]
                incr n
                lassign [deskCell {*}$xy] c r
                if {[lsearch -exact $placed "$c,$r"] < 0} break
            }
        }
        lassign [deskCell {*}$xy] c r
        lappend placed "$c,$r"
        deskIcon $i $ik $title $cmd [lindex $xy 0] [lindex $xy 1] $key
        if {$key ne "pc" && $key ne "trash"} {
            set ::deskPath([lindex $::deskIcons end]) $key
        }
        incr i
    }
    raiseDeskIcons
}
proc deskShort {s} {
    if {[string length $s] <= 16} { return $s }
    return "[string range $s 0 14]..."
}
proc deskIcon {row kind title cmd x y key} {
    set f .desk.di$row
    frame $f -bg #111111 -cursor hand2
    canvas $f.c -width 48 -height 40 -bg #111111 -highlightthickness 0 -cursor hand2
    pack $f.c
    drawIcon $f.c $kind
    label $f.t -text $title -bg #111111 -fg #f4f4f4 -font task -justify center -wraplength 88
    pack $f.t -padx 4
    place $f -x $x -y $y
    lappend ::deskIcons $f
    set ::deskKey($f) $key
    foreach w [list $f $f.c $f.t] {
        bind $w <Button-1> [list deskPress $f %X %Y]
        bind $w <Double-Button-1> $cmd
        bind $w <Button-3> [list deskIconMenu $f %X %Y]
    }
}
proc deskPress {f x y} {
    hideCtx
    deskSelect $f
    set ::deskGrab $f
    set ::deskDrag 0
    set ::deskPX $x
    set ::deskPY $y
    set ::deskOX [winfo x $f]
    set ::deskOY [winfo y $f]
    set ::deskHover ""
}
proc deskMove {x y} {
    if {![info exists ::deskGrab] || $::deskGrab eq ""} return
    set f $::deskGrab
    if {![winfo exists $f]} { set ::deskGrab ""; return }
    set dx [expr {$x - $::deskPX}]
    set dy [expr {$y - $::deskPY}]
    if {!$::deskDrag} {
        if {abs($dx) + abs($dy) < 4} return
        set ::deskDrag 1
        raise $f
        if {[winfo exists .desk.bar]} { raise .desk.bar }
        if {[winfo exists .desk.menu] && [winfo ismapped .desk.menu]} { raise .desk.menu }
    }
    set nx [expr {$::deskOX + $dx}]
    set ny [expr {$::deskOY + $dy}]
    if {$nx < 0} { set nx 0 }
    if {$ny < 0} { set ny 0 }
    if {$nx > $::SW - 96} { set nx [expr {$::SW - 96}] }
    if {$ny > $::SH - $::BARH - 88} { set ny [expr {$::SH - $::BARH - 88}] }
    place $f -x $nx -y $ny
    deskMarkHover [deskHit $f $x $y]
}
proc deskHit {self rx ry} {
    set x [expr {$rx - [winfo rootx .desk]}]
    set y [expr {$ry - [winfo rooty .desk]}]
    set best ""
    set bestD 1000000
    if {![info exists ::deskIcons]} { return "" }
    foreach w $::deskIcons {
        if {$w eq $self || ![winfo exists $w]} continue
        set ix [winfo x $w]
        set iy [winfo y $w]
        set iw [winfo width $w]
        set ih [winfo height $w]
        if {$iw < 8} { set iw 96 }
        if {$ih < 8} { set ih 84 }
        if {$x < $ix || $y < $iy || $x > $ix + $iw || $y > $iy + $ih} continue
        set d [expr {abs($x - ($ix + $iw / 2)) + abs($y - ($iy + $ih / 2))}]
        if {$d < $bestD} {
            set best $w
            set bestD $d
        }
    }
    return $best
}
proc deskCanDrop {src dst} {
    if {![info exists ::deskPath($src)] || ![info exists ::deskKey($dst)]} { return 0 }
    if {$::deskKey($dst) eq "trash"} { return 1 }
    if {$::deskKey($dst) eq "pc" || ![info exists ::deskPath($dst)]} { return 0 }
    set from [file normalize $::deskPath($src)]
    set to [file normalize $::deskPath($dst)]
    if {![file isdirectory $to]} { return 0 }
    if {$from eq $to} { return 0 }
    if {[string match $from/* $to]} { return 0 }
    return 1
}
proc deskMarkHover {w} {
    if {[info exists ::deskHover] && $::deskHover eq $w} return
    if {[info exists ::deskHover] && $::deskHover ne "" && [winfo exists $::deskHover]} {
        if {[info exists ::deskSel] && $::deskSel eq $::deskHover} {
            deskTint $::deskHover #1d4f91
        } else {
            deskTint $::deskHover #111111
        }
    }
    set ::deskHover $w
    if {$w eq "" || ![winfo exists $w] || ![info exists ::deskGrab]} return
    if {![deskCanDrop $::deskGrab $w]} return
    if {[info exists ::deskKey($w)] && $::deskKey($w) eq "trash"} {
        deskTint $w #6b2a2a
    } else {
        deskTint $w #1d4f91
    }
}
proc deskDrop {f} {
    set moved 0
    if {[info exists ::deskDrag]} { set moved $::deskDrag }
    set ::deskDrag 0
    set hover ""
    if {[info exists ::deskHover]} { set hover $::deskHover }
    set ::deskHover ""
    if {!$moved || ![winfo exists $f]} {
        if {$hover ne "" && [winfo exists $hover]} { deskTint $hover #111111 }
        if {[info exists ::deskSel] && [winfo exists $::deskSel]} { deskTint $::deskSel #1d4f91 }
        return
    }
    if {$hover ne "" && [winfo exists $hover] && [deskCanDrop $f $hover]} {
        set src $::deskPath($f)
        if {$::deskKey($hover) eq "trash"} {
            if {[trashPut $src]} {
                notify "Корзина" "Перемещено в корзину: [file tail $src]"
                paintDeskIcons
                if {[winfo exists .wfiles]} { catch {filesRefresh} }
                if {[winfo exists .wtrash]} { catch {trashRender} }
                return
            }
        } else {
            set dir $::deskPath($hover)
            set dest [filesUnique [file join $dir [file tail $src]]]
            if {![catch {file rename $src $dest}]} {
                notify "Рабочий стол" "Перемещено в [file tail $dir]: [file tail $src]"
                paintDeskIcons
                if {[winfo exists .wfiles]} { catch {filesRefresh} }
                return
            }
        }
    }
    if {$hover ne "" && [winfo exists $hover]} { deskTint $hover #111111 }
    if {![winfo exists $f]} return
    lassign [deskSnap $f [winfo x $f] [winfo y $f]] sx sy
    place $f -x $sx -y $sy
    deskSaveAllPos
    deskSelect $f
}
proc deskSelect {f} {
    if {[info exists ::deskSel] && $::deskSel ne "" && [winfo exists $::deskSel] && $::deskSel ne $f} {
        deskTint $::deskSel #111111
    }
    set ::deskSel $f
    deskTint $f #1d4f91
}
proc deskTint {f bg} {
    if {![winfo exists $f]} return
    $f configure -bg $bg
    foreach c [winfo children $f] { catch { $c configure -bg $bg } }
}
proc deskOpen {path} {
    hideStart
    hideCtx
    if {[file isdirectory $path]} { openFiles $path } else { openByType $path }
}
proc deskIconMenu {f x y} {
    catch { destroy .dmenu }
    if {![info exists ::deskPath($f)]} return
    set path $::deskPath($f)
    deskSelect $f
    toplevel .dmenu
    wm overrideredirect .dmenu 1
    .dmenu configure -bg #3a3a3a
    frame .dmenu.f -bg #2c2c2c
    pack .dmenu.f -padx 1 -pady 1
    label .dmenu.f.o -text "Открыть" -bg #2c2c2c -fg #f3f3f3 -font task -anchor w -padx 16 -pady 7 -cursor hand2
    label .dmenu.f.d -text "Удалить" -bg #2c2c2c -fg #f3f3f3 -font task -anchor w -padx 16 -pady 7 -cursor hand2
    pack .dmenu.f.o .dmenu.f.d -fill x
    bind .dmenu.f.o <Button-1> [list deskMenuOpen $path]
    bind .dmenu.f.d <Button-1> [list deskMenuTrash $path]
    bind .dmenu.f.o <Enter> {.dmenu.f.o configure -bg #383838}
    bind .dmenu.f.o <Leave> {.dmenu.f.o configure -bg #2c2c2c}
    bind .dmenu.f.d <Enter> {.dmenu.f.d configure -bg #383838}
    bind .dmenu.f.d <Leave> {.dmenu.f.d configure -bg #2c2c2c}
    set mw 160
    set mh 70
    set rx [expr {$x - [winfo rootx .desk]}]
    set ry [expr {$y - [winfo rooty .desk]}]
    if {$rx + $mw > $::SW} { set rx [expr {$::SW - $mw - 4}] }
    if {$ry + $mh > $::SH - $::BARH} { set ry [expr {$::SH - $::BARH - $mh - 4}] }
    wm geometry .dmenu +$rx+$ry
    raise .dmenu
}
proc deskMenuOpen {path} {
    catch { destroy .dmenu }
    deskOpen $path
}
proc deskMenuTrash {path} {
    catch { destroy .dmenu }
    trashPut $path
    paintDeskIcons
    if {[winfo exists .wfiles]} { catch {filesRefresh} }
    if {[winfo exists .wtrash]} { trashRender }
}
proc raiseDeskIcons {} {
    if {![info exists ::deskIcons]} return
    foreach w $::deskIcons {
        if {[winfo exists $w]} { raise $w }
    }
    if {[winfo exists .desk.bar]} { raise .desk.bar }
    if {[winfo exists .desk.menu] && [winfo ismapped .desk.menu]} { raise .desk.menu }
    if {[winfo exists .desk.ctx] && [winfo ismapped .desk.ctx]} { raise .desk.ctx }
    clockRaise
}

proc openViewer {path} {
    set id v[clock milliseconds]
    set ::pinicon($id) doc
    set w [newWindow $id [file tail $path] 640 460]
    text $w.in.b.t -bg $::TERM -fg $::WHITE -font mono -highlightthickness 0 -wrap word \
        -padx 14 -pady 14
    pack $w.in.b.t -fill both -expand 1 -padx 18 -pady 14
    $w.in.b.t insert end [readFile $path 80000]
    $w.in.b.t configure -state disabled
}

proc sunNorm {u} {
    set u [string trim $u]
    if {$u eq "" || $u eq "about:home"} { return "about:home" }
    if {![regexp {^[A-Za-z][A-Za-z0-9+.-]*:} $u]} { set u "https://$u" }
    return $u
}
proc sunResolve {base rel} {
    set rel [string trim $rel]
    if {$rel eq "" || [string match "#*" $rel]} { return "" }
    if {[string match -nocase "javascript:*" $rel]} { return "" }
    if {[regexp -nocase {^https?://} $rel]} { return $rel }
    if {[string match "//*" $rel]} { return "https:$rel" }
    if {![regexp {^(https?://[^/?#]+)([^?#]*)?} $base -> origin path]} { return $rel }
    if {[string match "/*" $rel]} { return "$origin$rel" }
    if {$path eq ""} { set path / }
    if {![string match "*/" $path]} {
        set slash [string last / $path]
        if {$slash < 0} {
            set path /
        } else {
            set path [string range $path 0 $slash]
        }
    }
    return "$origin$path$rel"
}
proc sunEntities {s} {
    set s [string map {
        &nbsp; " " &amp; & &lt; < &gt; > &quot; \" &#39; ' &apos; '
        &copy; © &reg; ® &trade; ™ &mdash; — &ndash; – &hellip; …
        &laquo; « &raquo; » &bull; • &middot; ·
    } $s]
    while {[regexp {&#(x[0-9A-Fa-f]+|[0-9]+);} $s -> n]} {
        if {[string match -nocase x* $n]} {
            scan [string range $n 1 end] %x code
        } else {
            set code $n
        }
        if {![string is integer -strict $code] || $code < 0 || $code > 1114111} {
            set s [string map [list "&#$n;" ""] $s]
            continue
        }
        set s [string map [list "&#$n;" [format %c $code]] $s]
    }
    return $s
}
proc sunDecode {s} {
    set s [sunEntities $s]
    regsub -all {[[:space:]]+} $s " " s
    return [string trim $s]
}
proc sunHome {} {
    return {<h1>Sun Browser</h1><p>Свой браузер DeepOS. Адрес в строке сверху, ссылки открываются по нажатию.</p><h2>С чего начать</h2><ul><li><a href="https://example.com">example.com</a></li><li><a href="https://example.org">example.org</a></li><li><a href="http://info.cern.ch">Первый сайт в интернете</a></li><li><a href="https://httpbin.org/html">Проверочная страница</a></li></ul>}
}
proc sunStatus {msg} {
    if {[winfo exists .wbrowse.in.b.stat]} { .wbrowse.in.b.stat configure -text $msg }
}
proc sunTool {w name text cmd} {
    label $w.$name -text $text -bg #2a2a2a -fg #f3f3f3 -font ui -padx 10 -pady 6 -cursor hand2
    pack $w.$name -side left -padx 2
    bind $w.$name <Button-1> $cmd
    bind $w.$name <Enter> [list $w.$name configure -bg #3a3a3a]
    bind $w.$name <Leave> [list $w.$name configure -bg #2a2a2a]
}
proc openFirefox {} {
    if {[guestDenied Firefox /usr/bin/firefox]} { return }
    set ::hostPids(firefox) {firefox firefox-bin}
    openHostApp firefox Firefox \
        {deepos-wmhint; deepos-firefox-frame; XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_DESKTOP=gnome GDK_BACKEND=x11 GTK_CSD=1 MOZ_GTK_TITLEBAR_DECORATION=client MOZ_ENABLE_WAYLAND=0 MOZ_DISABLE_CONTENT_SANDBOX=1 firefox --no-remote} \
        {firefox Firefox Navigator Mozilla mozilla}
}
proc openChrome {} {
    if {[guestDenied Chrome /usr/bin/chromium-browser]} { return }
    set ::hostPids(chrome) {chromium chromium-browser chrome}
    openHostApp chrome Chrome \
        {deepos-wmhint; deepos-chrome-frame; XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_DESKTOP=gnome GDK_BACKEND=x11 chromium-browser --no-sandbox --disable-dev-shm-usage --ozone-platform=x11 --enable-features=UseOzonePlatform || XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_DESKTOP=gnome GDK_BACKEND=x11 chromium --no-sandbox --disable-dev-shm-usage --ozone-platform=x11 --enable-features=UseOzonePlatform} \
        {chromium Chromium chromium-browser Chromium-browser google-chrome Google-chrome Chrome}
}
proc hostSeenNow {classes} {
    set ids {}
    foreach class $classes {
        if {[catch {exec xdotool search --class $class} out]} continue
        foreach wid [split $out \n] {
            set wid [string trim $wid]
            if {[string is integer -strict $wid]} { lappend ids $wid }
        }
    }
    return $ids
}
proc openExe {path} {
    if {![file exists $path]} {
        notify "Программа" "Файл не найден"
        return
    }
    set id exe[clock milliseconds]
    set ::pinicon($id) exe
    set title [file rootname [file tail $path]]
    set ::title($id) $title
    set classes [list wine Wine [file tail $path] [file rootname [file tail $path]]]
    set ::hostSeen($id) [hostSeenNow $classes]
    set q [string map {' '\\''} $path]
    openHostApp $id $title "exec /usr/bin/deepos-exe '$q'" $classes
}
proc openHostApp {id title shell classes} {
    set w [newWindow $id $title 1100 720]
    set b $w.in.b
    set ::hostClass($id) $classes
    set ::hostShell($id) $shell
    if {[winfo exists $b.host]} {
        hostFit $id
        if {![info exists ::hostGrab($id)]} {
            set ::hostGrab($id) [after 200 [list hostGrab $id]]
        }
        return
    }
    $b configure -bg #202124
    frame $b.host -bg #202124
    pack $b.host -fill both -expand 1
    label $b.host.wait -text "Запускаю $title…" -bg #202124 -fg #f3f3f3 -font title
    place $b.host.wait -relx 0.5 -rely 0.42 -anchor center
    bind $b.host <Configure> [list hostFit $id]
    hostLaunch $id
}
proc hostLaunch {id} {
    if {![info exists ::hostShell($id)]} return
    if {[catch {open [list | /bin/sh -c "$::hostShell($id) >>/tmp/host-$id.log 2>&1"] r} pipe]} {
        if {[winfo exists .w$id.in.b.host.wait]} {
            .w$id.in.b.host.wait configure -text "Не удалось запустить"
        }
        return
    }
    fconfigure $pipe -blocking 0
    set ::hostPipe($id) $pipe
    fileevent $pipe readable [list hostDrain $id $pipe]
    set ::hostTries($id) 0
    set ::hostGrab($id) [after 800 [list hostGrab $id]]
}
proc hostDrain {id pipe} {
    if {[catch {read $pipe} chunk]} {
        catch { close $pipe }
        unset -nocomplain ::hostPipe($id)
        return
    }
    if {[catch {eof $pipe} done] || !$done} return
    catch { close $pipe }
    unset -nocomplain ::hostPipe($id)
}
proc hostStop {id} {
    if {[info exists ::hostGrab($id)]} {
        after cancel $::hostGrab($id)
        unset ::hostGrab($id)
    }
    if {[info exists ::hostPipe($id)]} {
        set p $::hostPipe($id)
        unset ::hostPipe($id)
        catch { fileevent $p readable {} }
        catch { exec kill [lindex [pid $p] 0] }
        catch { fconfigure $p -blocking 0 }
        catch { close $p }
    }
    if {$id eq "firefox"} {
        catch {exec sh -c {for p in $(pidof firefox firefox-bin); do kill $p; done}}
    } elseif {$id eq "chrome"} {
        catch {exec sh -c {for p in $(pidof chromium chromium-browser chrome); do kill $p; done}}
    } elseif {[info exists ::hostBin($id)] && $::hostBin($id) ne ""} {
        set b $::hostBin($id)
        catch {exec sh -c "for p in \$(pidof $b); do kill \$p; done"}
    } elseif {[string match exe* $id]} {
        set others 0
        foreach w $::wins {
            if {$w ne $id && [string match exe* $w] && [winfo exists .w$w]} { set others 1 }
        }
        if {!$others} {
            catch {exec sh -c {for p in $(pidof wine wine64 wineserver); do kill $p; done}}
        }
    }
    set ::hostXid($id) ""
}
proc xwinScreen {wid} {
    if {[catch {exec xdotool getwindowgeometry $wid} geo]} { return {} }
    if {![regexp {screen: (-?[0-9]+),(-?[0-9]+)} $geo -> sx sy]} { return {} }
    if {![regexp {Geometry: ([0-9]+)x([0-9]+)} $geo -> w h]} { return {} }
    return [list $sx $sy $w $h]
}
proc xwinAdd {idsVar out} {
    upvar $idsVar ids
    foreach wid [split $out \n] {
        set wid [string trim $wid]
        if {![string is integer -strict $wid]} continue
        if {[lsearch -exact $ids $wid] >= 0} continue
        lappend ids $wid
    }
}
proc xwinList {classes} {
    set ids {}
    foreach class $classes {
        foreach flag {--class --classname --name} {
            if {[catch {exec xdotool search $flag $class} out]} continue
            xwinAdd ids $out
        }
    }
    return $ids
}
proc xwinByPids {names} {
    if {[llength $names] == 0} { return {} }
    if {[catch {eval exec pidof $names} raw]} { return {} }
    set ids {}
    foreach pid [split [string trim $raw]] {
        if {![string is integer -strict $pid]} continue
        if {[catch {exec xdotool search --pid $pid} out]} continue
        xwinAdd ids $out
    }
    return $ids
}
proc xwinFor {classes pnames} {
    set ids [xwinList $classes]
    foreach wid [xwinByPids $pnames] {
        if {[lsearch -exact $ids $wid] < 0} { lappend ids $wid }
    }
    return $ids
}
proc embedSync {wid parent} {
    if {$wid eq "" || ![winfo exists $parent]} { return }
    set hw [winfo width $parent]
    set hh [winfo height $parent]
    if {$hw < 40 || $hh < 40} { return }
    set hx [winfo rootx $parent]
    set hy [winfo rooty $parent]
    set geo [xwinScreen $wid]
    if {[llength $geo] == 4} {
        lassign $geo sx sy w h
        if {abs($sx - $hx) < 48 && abs($sy - $hy) < 48} {
            return
        }
    }
    scan [winfo id $parent] %x p
    catch {exec xdotool windowunmap $wid}
    catch {exec xdotool windowreparent $wid $p}
    catch {exec xdotool windowmap $wid}
    catch {exec xdotool windowmove $wid 0 0}
    catch {exec xdotool windowsize $wid $hw $hh}
}
proc hostPick {id} {
    set best ""
    set bestA 0
    if {![info exists ::hostClass($id)]} { return "" }
    foreach class $::hostClass($id) {
        if {[catch {exec xdotool search --class $class} out]} continue
        foreach wid [split $out \n] {
            set wid [string trim $wid]
            if {![string is integer -strict $wid]} continue
            if {[info exists ::hostSeen($id)] && [lsearch -exact $::hostSeen($id) $wid] >= 0} continue
            if {[catch {exec xdotool getwindowgeometry $wid} geo]} continue
            if {![regexp {Geometry: ([0-9]+)x([0-9]+)} $geo -> w h]} continue
            set area [expr {$w * $h}]
            if {$area > $bestA} {
                set bestA $area
                set best $wid
            }
        }
    }
    return $best
}
proc hostGrab {id} {
    set parent .w$id.in.b.host
    if {![winfo exists $parent]} { return }
    if {![winfo exists .w$id] || ![winfo viewable .w$id]} {
        if {[winfo exists $parent]} { set ::hostGrab($id) [after 700 [list hostGrab $id]] }
        return
    }
    if {[info exists ::hostXid($id)] && $::hostXid($id) ne ""} {
        if {[llength [xwinScreen $::hostXid($id)]] == 4} {
            if {[winfo exists $parent]} { set ::hostGrab($id) [after 2000 [list hostGrab $id]] }
            return
        }
        set ::hostXid($id) ""
        unset -nocomplain ::hostFitSize($id)
    }
    set found {}
    if {[info exists ::hostClass($id)]} {
        set pnames {}
        if {[info exists ::hostPids($id)]} { set pnames $::hostPids($id) }
        foreach wid [xwinFor $::hostClass($id) $pnames] {
            if {[info exists ::hostSeen($id)] && [lsearch -exact $::hostSeen($id) $wid] >= 0} continue
            set geo [xwinScreen $wid]
            if {[llength $geo] != 4} continue
            lassign $geo sx sy w h
            if {$w < 320 || $h < 200} continue
            lappend found $wid
        }
    }
    set best ""
    if {[llength $found] > 0} { set best [lindex [lsort -integer $found] end] }
    if {$best eq ""} {
        if {![info exists ::hostTries($id)]} { set ::hostTries($id) 0 }
        incr ::hostTries($id)
        if {$::hostTries($id) == 40 && [winfo exists $parent.wait]} {
            $parent.wait configure -text "Окно не появилось"
        }
    } else {
        set ::hostXid($id) $best
        if {[winfo exists $parent.wait]} { place forget $parent.wait }
        foreach wid [lsort -integer $found] { embedSync $wid $parent }
    }
    if {[winfo exists $parent]} {
        set ::hostGrab($id) [after 300 [list hostGrab $id]]
    }
}
proc hostFit {id} {
    if {![info exists ::hostXid($id)] || $::hostXid($id) eq ""} return
    if {![winfo exists .w$id.in.b.host]} return
    set w [winfo width .w$id.in.b.host]
    set h [winfo height .w$id.in.b.host]
    if {$w < 40 || $h < 40} return
    if {[info exists ::hostFitSize($id)] && $::hostFitSize($id) eq "$w $h"} return
    set ::hostFitSize($id) "$w $h"
    catch {exec xdotool windowmove $::hostXid($id) 0 0}
    catch {exec xdotool windowsize $::hostXid($id) $w $h}
}
proc browserLink {title bin pkg} {
    if {![file executable $bin]} return
    file mkdir /root/Desktop
    set path [file join /root/Desktop "$title.deepos"]
    if {[file exists $path]} return
    set fh [open $path w]
    puts $fh "title=$title"
    puts $fh "bin=$bin"
    puts $fh "pkg=$pkg"
    puts $fh "gui=1"
    close $fh
}
proc browserLinks {} {
    set chrome /usr/bin/chromium-browser
    if {![file executable $chrome]} { set chrome /usr/bin/chromium }
    browserLink Firefox /usr/bin/firefox firefox
    browserLink Chrome $chrome chrome
    paintDeskIcons
}
proc openBrowse {} {
    set w [newWindow browse "Sun Browser" 1040 680]
    set b $w.in.b
    if {[winfo exists $b.bar]} {
        focus $b.bar.url
        return
    }
    set ::sunTabs {}
    set ::sunCur ""
    set ::sunSeq 0
    frame $b.tabs -bg #161616 -height 40
    pack $b.tabs -fill x
    pack propagate $b.tabs 0
    frame $b.tabs.row -bg #161616
    pack $b.tabs.row -side left -fill y
    label $b.tabs.add -text "  +  " -bg #161616 -fg #f3f3f3 -font ui -cursor hand2
    pack $b.tabs.add -side left -padx 4
    bind $b.tabs.add <Button-1> sunNewTab
    bind $b.tabs.add <Enter> [list $b.tabs.add configure -bg #2a2a2a]
    bind $b.tabs.add <Leave> [list $b.tabs.add configure -bg #161616]
    frame $b.bar -bg #2a2a2a
    pack $b.bar -fill x -pady 6
    sunTool $b.bar back "←" sunBack
    sunTool $b.bar fwd "→" sunFwd
    sunTool $b.bar rel "↻" sunReload
    sunTool $b.bar home "⌂" {sunNavigate about:home}
    entry $b.bar.url -bg #111111 -fg #f6f6f6 -insertbackground #ffb020 -font ui \
        -highlightthickness 1 -highlightbackground #3a3a3a -highlightcolor #ffb020 -bd 0
    pack $b.bar.url -side left -fill x -expand 1 -padx 8 -ipady 7
    bind $b.bar.url <Return> {sunNavigate [.wbrowse.in.b.bar.url get]}
    frame $b.view -bg #f7f7f7
    pack $b.view -fill both -expand 1
    label $b.stat -text "Готово" -bg #1b1b1b -fg #bdbdbd -font small -anchor w -padx 12 -pady 4
    pack $b.stat -fill x
    frame $b.host -bg #ffffff
    label $b.host.wait -text "Открываю страницу…" -bg #ffffff -fg #202124 -font title
    place $b.host.wait -relx 0.5 -rely 0.42 -anchor center
    bind $b.host <Configure> sunEngineFit
    sunNewTab
    focus $b.bar.url
}
proc sunNewTab {{url about:home}} {
    if {[llength $::sunTabs] >= 8} { return }
    incr ::sunSeq
    set id t$::sunSeq
    set b .wbrowse.in.b
    lappend ::sunTabs $id
    set ::hist($id) {}
    set ::histi($id) -1
    set ::loc($id) ""
    frame $b.tabs.row.$id -bg #2a2a2a -cursor hand2
    pack $b.tabs.row.$id -side left -padx 1 -pady 6
    label $b.tabs.row.$id.n -text "Новая вкладка" -bg #2a2a2a -fg #f3f3f3 -font task -padx 8
    label $b.tabs.row.$id.x -text "×" -bg #2a2a2a -fg #c8c8c8 -font task -padx 6 -cursor hand2
    pack $b.tabs.row.$id.n $b.tabs.row.$id.x -side left
    bind $b.tabs.row.$id <Button-1> [list sunShow $id]
    bind $b.tabs.row.$id.n <Button-1> [list sunShow $id]
    bind $b.tabs.row.$id.x <Button-1> [list sunCloseTab $id]
    text $b.view.$id -bg #f7f7f7 -fg #1c1c1c -font ui -wrap word -padx 28 -pady 18 \
        -highlightthickness 0 -insertwidth 0 -cursor arrow
    $b.view.$id tag configure h1 -font title -spacing1 8 -spacing3 6
    $b.view.$id tag configure h2 -font uib -spacing1 8 -spacing3 4
    $b.view.$id tag configure p -spacing1 2 -spacing3 6
    $b.view.$id tag configure link -underline 1
    $b.view.$id tag configure linkfg -foreground #0b57d0 -underline 1
    $b.view.$id tag bind link <Enter> [list $b.view.$id configure -cursor hand2]
    $b.view.$id tag bind link <Leave> [list $b.view.$id configure -cursor arrow]
    bind $b.view.$id <Button-1> [list sunClick %W %x %y]
    bind $b.view.$id <Key> break
    bind $b.view.$id <Button-4> [list %W yview scroll -3 units]
    bind $b.view.$id <Button-5> [list %W yview scroll 3 units]
    set ::page($id) $b.view.$id
    sunShow $id
    sunNavigate $url
}
proc sunShow {id} {
    if {[lsearch -exact $::sunTabs $id] < 0} return
    set ::sunCur $id
    set b .wbrowse.in.b
    foreach t $::sunTabs {
        pack forget $b.view.$t
        $b.tabs.row.$t configure -bg #2a2a2a
        $b.tabs.row.$t.n configure -bg #2a2a2a
        $b.tabs.row.$t.x configure -bg #2a2a2a
    }
    if {[info exists ::loc($id)] && [regexp {^https?://} $::loc($id)]} {
        sunEngineGo $::loc($id)
    } else {
        pack $b.view.$id -fill both -expand 1
        if {[winfo exists $b.host]} { pack forget $b.host }
    }
    $b.tabs.row.$id configure -bg #3f3f3f
    $b.tabs.row.$id.n configure -bg #3f3f3f
    $b.tabs.row.$id.x configure -bg #3f3f3f
    $b.bar.url delete 0 end
    if {[info exists ::loc($id)]} { $b.bar.url insert 0 $::loc($id) }
}
proc sunStop {id} {
    if {![info exists ::sunPipe($id)]} return
    set p $::sunPipe($id)
    unset -nocomplain ::sunPipe($id)
    catch { fileevent $p readable {} }
    catch { exec kill [lindex [pid $p] 0] }
    catch { fconfigure $p -blocking 0 }
    catch { close $p }
}
proc sunStopAll {} {
    sunEngineStop
    if {![info exists ::sunTabs]} return
    foreach id $::sunTabs { sunStop $id }
    set ::sunTabs {}
    set ::sunCur ""
}
proc sunCloseTab {id} {
    sunStop $id
    set b .wbrowse.in.b
    set i [lsearch -exact $::sunTabs $id]
    if {$i < 0} return
    set ::sunTabs [lreplace $::sunTabs $i $i]
    destroy $b.tabs.row.$id
    destroy $b.view.$id
    unset -nocomplain ::hist($id) ::histi($id) ::loc($id) ::page($id)
    if {[llength $::sunTabs] == 0} {
        closeWin browse
        return
    }
    if {$::sunCur eq $id} {
        set next [lindex $::sunTabs [expr {$i > 0 ? $i - 1 : 0}]]
        sunShow $next
    }
}
proc sunBack {} {
    set id $::sunCur
    if {![info exists ::histi($id)] || $::histi($id) <= 0} return
    incr ::histi($id) -1
    sunLoad $id [lindex $::hist($id) $::histi($id)]
}
proc sunFwd {} {
    set id $::sunCur
    if {![info exists ::hist($id)]} return
    if {$::histi($id) >= [llength $::hist($id)] - 1} return
    incr ::histi($id)
    sunLoad $id [lindex $::hist($id) $::histi($id)]
}
proc sunReload {} {
    set id $::sunCur
    if {![info exists ::loc($id)] || $::loc($id) eq ""} return
    sunLoad $id $::loc($id)
}
proc sunNavigate {url {post ""}} {
    set url [sunNorm $url]
    set id $::sunCur
    if {$id eq ""} return
    if {![info exists ::hist($id)]} { set ::hist($id) {}; set ::histi($id) -1 }
    set ::hist($id) [lrange $::hist($id) 0 $::histi($id)]
    lappend ::hist($id) $url
    set ::histi($id) [expr {[llength $::hist($id)] - 1}]
    sunLoad $id $url $post
}
proc sunEncode {s} {
    set bytes [encoding convertto utf-8 $s]
    set out ""
    foreach ch [split $bytes ""] {
        set code [scan $ch %c]
        if {($code >= 65 && $code <= 90) || ($code >= 97 && $code <= 122) || ($code >= 48 && $code <= 57) || [string match {[._~-]} $ch]} {
            append out $ch
        } elseif {$ch eq " "} {
            append out "+"
        } else {
            append out %[format %02X $code]
        }
    }
    return $out
}
proc sunSubmit {fid} {
    if {![info exists ::ffields($fid)]} return
    set parts {}
    foreach item $::ffields($fid) {
        lassign $item kind name val
        if {$kind eq "text"} {
            if {![winfo exists $val]} continue
            set val [$val get]
        }
        lappend parts "[sunEncode $name]=[sunEncode $val]"
    }
    set q [join $parts &]
    set action $::faction($fid)
    if {$::fmethod($fid) eq "post"} {
        sunNavigate $action $q
    } else {
        set joiner ?
        if {[string first ? $action] >= 0} { set joiner & }
        sunNavigate "$action$joiner$q"
    }
}
proc sunFormInput {t fid raw} {
    set type text
    set iname ""
    set ival ""
    regexp -nocase {type\s*=\s*["']([^"']+)["']} $raw -> type
    regexp -nocase {name\s*=\s*["']([^"']+)["']} $raw -> iname
    if {$iname eq ""} { regexp -nocase {name\s*=\s*([^\s"'>]+)} $raw -> iname }
    regexp -nocase {value\s*=\s*["']([^"']*)["']} $raw -> ival
    set ival [sunEntities $ival]
    set type [string tolower $type]
    if {$type eq "hidden"} {
        if {$iname eq ""} return
        lappend ::ffields($fid) [list hidden $iname $ival]
        return
    }
    if {$type in {submit button image}} {
        set label [string trim $ival]
        if {$label eq ""} { set label "Перейти" }
        incr ::formSeq
        set b $t.b$::formSeq
        button $b -text $label -command [list sunSubmit $fid] -bg #0b57d0 -fg #ffffff \
            -activebackground #0842a0 -font ui -padx 12 -pady 4 -cursor hand2
        set st [sunActiveStyle]
        if {[dict exists $st bg]} {
            $b configure -bg [dict get $st bg] -activebackground [dict get $st bg]
        }
        if {[dict exists $st fg]} { $b configure -fg [dict get $st fg] }
        $t window create end -window $b -padx 6 -pady 2
        return
    }
    if {$type ni {text search url email password}} return
    if {$iname eq ""} return
    incr ::formSeq
    set e $t.e$::formSeq
    set wide 32
    set st [sunActiveStyle]
    if {[dict exists $st width]} {
        set wide [expr {max(12, min(64, [dict get $st width] / 9))}]
    } elseif {$iname eq "q" || $type eq "search"} {
        set wide 48
    }
    entry $e -bg #ffffff -fg #1c1c1c -font ui -width $wide -insertbackground #1c1c1c
    if {[dict exists $st bg]} { $e configure -bg [dict get $st bg] }
    if {[dict exists $st fg]} { $e configure -fg [dict get $st fg] -insertbackground [dict get $st fg] }
    if {$type eq "password"} { $e configure -show "*" }
    if {$ival ne ""} { $e insert 0 $ival }
    $t window create end -window $e -padx 4 -pady 3
    lappend ::ffields($fid) [list text $iname $e]
    bind $e <Return> [list sunSubmit $fid]
}
proc sunClick {w x y} {
    set tags [$w tag names @$x,$y]
    foreach tag $tags {
        if {[info exists ::href($tag)]} {
            sunNavigate $::href($tag)
            return -code break
        }
    }
}
proc sunEnsureNl {t} {
    if {[$t index end-1c] eq "1.0"} return
    set ch [$t get "end-2c" "end-1c"]
    if {$ch ne "\n"} { $t insert end "\n" }
}
proc sunRenderPage {id url html} {
    set t $::page($id)
    $t configure -state normal
    foreach c [winfo children $t] { destroy $c }
    $t delete 1.0 end
    set title ""
    if {[regexp -nocase {<title[^>]*>([^<]*)</title>} $html -> raw]} {
        set title [sunDecode $raw]
    }
    set ::linkn 0
    set ::imgn 0
    if {[catch {sunWalk $t $html $url} err]} {
        $t insert end "\nНе удалось показать часть страницы.\n"
    }
    set ::loc($id) $url
    if {$title eq ""} { set title $url }
    if {[string length $title] > 22} {
        set tab "[string range $title 0 20]..."
    } else {
        set tab $title
    }
    if {[winfo exists .wbrowse.in.b.tabs.row.$id.n]} {
        .wbrowse.in.b.tabs.row.$id.n configure -text $tab
    }
    if {$::sunCur eq $id} {
        .wbrowse.in.b.bar.url delete 0 end
        .wbrowse.in.b.bar.url insert 0 $url
        .wbrowse.in.bar.h configure -text "Sun Browser  —  $title"
        set ::title(browse) "Sun Browser"
        paintPins
    }
    sunStatus "Готово"
}
proc sunCssColor {c} {
    set c [string tolower [string trim $c]]
    regsub -all {!important} $c "" c
    set c [string trim $c]
    if {$c eq "" || $c eq "transparent" || $c eq "none" || $c eq "inherit"} { return "" }
    if {[regexp {^var\([^,]+,\s*(.+)\)$} $c -> inner]} { return [sunCssColor $inner] }
    if {[regexp {^#([0-9a-f]{3})$} $c -> h]} {
        return #[string index $h 0][string index $h 0][string index $h 1][string index $h 1][string index $h 2][string index $h 2]
    }
    if {[regexp {^#([0-9a-f]{6})} $c -> h]} { return "#$h" }
    if {[regexp {^rgba?\(\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([0-9]+)} $c -> r g b]} {
        return [format "#%02x%02x%02x" $r $g $b]
    }
    array set named {white #ffffff black #1f1f1f red #c5221f blue #0b57d0 gray #5f6368 grey #5f6368 green #188038}
    if {[info exists named($c)]} { return $named($c) }
    return ""
}
proc sunCssBody {body} {
    set d [dict create]
    foreach decl [split $body ";"] {
        set decl [string trim $decl]
        if {![regexp {^([A-Za-z-]+)\s*:\s*(.+)$} $decl -> prop val]} continue
        set prop [string tolower $prop]
        regsub -all {!important} $val "" val
        set val [string trim $val]
        switch -- $prop {
            color {
                set col [sunCssColor $val]
                if {$col ne ""} { dict set d fg $col }
            }
            background-color {
                set col [sunCssColor $val]
                if {$col ne ""} { dict set d bg $col }
            }
            background {
                set col [sunCssColor $val]
                if {$col eq "" && [regexp {#[0-9a-fA-F]{3,8}|rgba?\([^)]+\)} $val hit]} {
                    set col [sunCssColor $hit]
                }
                if {$col ne ""} { dict set d bg $col }
            }
            font-weight {
                if {$val in {bold bolder} || ([string is integer -strict $val] && $val >= 600)} {
                    dict set d bold 1
                }
            }
            font-size {
                if {[regexp {^([0-9]+)px} $val -> px]} { dict set d size $px }
            }
            text-align {
                if {$val in {left center right}} { dict set d align $val }
            }
            justify-content {
                if {[string match *center* $val]} { dict set d align center }
            }
            display {
                if {$val eq "none"} { dict set d hide 1 }
            }
            width {
                if {[regexp {^([0-9]+)px} $val -> px]} { dict set d width $px }
            }
        }
    }
    return $d
}
proc sunCssRules {css} {
    regsub -all {(?s)/\*.*?\*/} $css "" css
    set rules {}
    set n [string length $css]
    set i 0
    while {$i < $n && [llength $rules] < 2500} {
        set brace [string first "\{" $css $i]
        if {$brace < 0} break
        set sel [string trim [string range $css $i [expr {$brace - 1}]]]
        set depth 1
        set j [expr {$brace + 1}]
        while {$j < $n && $depth > 0} {
            set c [string index $css $j]
            if {$c eq "\{"} { incr depth }
            if {$c eq "\}"} { incr depth -1 }
            incr j
        }
        set body [string range $css [expr {$brace + 1}] [expr {$j - 2}]]
        if {[string match -nocase "@media*" $sel] || [string match -nocase "@supports*" $sel]} {
            foreach sub [sunCssRules $body] {
                if {[llength $rules] >= 2500} break
                lappend rules $sub
            }
        } elseif {![string match "@*" $sel] && $sel ne ""} {
            set props [sunCssBody $body]
            if {[dict size $props] > 0} { lappend rules [list $sel $props] }
        }
        set i $j
    }
    return $rules
}
proc sunGatherCss {html base} {
    set blob ""
    set start 0
    while {[regexp -nocase -indices -start $start {(?s)<style[^>]*>(.*?)</style>} $html -> span]} {
        append blob [string range $html [lindex $span 0] [lindex $span 1]] "\n"
        set start [expr {[lindex $span 1] + 1}]
    }
    set start 0
    set nsheets 0
    while {$nsheets < 3 && [regexp -nocase -indices -start $start {<link\b[^>]*>} $html span]} {
        set tag [string range $html [lindex $span 0] [lindex $span 1]]
        set start [expr {[lindex $span 1] + 1}]
        if {![regexp -nocase {stylesheet} $tag]} continue
        if {![regexp -nocase {href\s*=\s*["']([^"']+)["']} $tag -> href]} continue
        set abs [sunResolve $base $href]
        if {$abs eq ""} continue
        incr nsheets
        sunStatus "Стили $nsheets"
        set tmp /tmp/sun-css$nsheets
        catch {exec curl -4 -sS -L --max-time 8 --max-filesize 400000 --dns-servers 1.1.1.1,8.8.8.8 -o $tmp -- $abs}
        if {![file exists $tmp]} continue
        if {[catch {
            set fh [open $tmp r]
            fconfigure $fh -encoding utf-8
            append blob [read $fh 400000] "\n"
            close $fh
        }]} continue
    }
    set ::sunCss [sunCssRules $blob]
}
proc sunApplyPageChrome {t} {
    foreach rule $::sunCss {
        lassign $rule sels props
        foreach sel [split $sels ","] {
            set sel [string trim $sel]
            if {$sel ne "body" && $sel ne "html"} continue
            if {[dict exists $props bg]} { $t configure -bg [dict get $props bg] }
            if {[dict exists $props fg]} { $t configure -fg [dict get $props fg] }
        }
    }
}
proc sunCompoundMatch {part tag classes id} {
    regsub -all {::?[A-Za-z0-9_-]+(\([^)]*\))?} $part "" part
    set part [string trim $part]
    if {$part eq "" || $part eq "*"} { return 1 }
    set wantTag ""
    set wantId ""
    set wantClass {}
    if {[regexp {^([A-Za-z0-9]+)} $part wantTag]} {
        set part [string range $part [string length $wantTag] end]
    } elseif {![string match {[.#]*} $part]} {
        return 0
    }
    while {$part ne ""} {
        if {[regexp {^\.([A-Za-z0-9_-]+)} $part -> cls]} {
            lappend wantClass $cls
            set part [string range $part [expr {[string length $cls] + 1}] end]
        } elseif {[regexp {^#([A-Za-z0-9_-]+)} $part -> wantId]} {
            set part [string range $part [expr {[string length $wantId] + 1}] end]
        } else {
            return 0
        }
    }
    if {$wantTag ne "" && $wantTag ne $tag} { return 0 }
    if {$wantId ne "" && $wantId ne $id} { return 0 }
    foreach cls $wantClass {
        if {[lsearch -exact $classes $cls] < 0} { return 0 }
    }
    return 1
}
proc sunSelectorMatch {sel tag classes id} {
    regsub -all {::?[A-Za-z0-9_-]+(\([^)]*\))?} $sel "" sel
    set bits {}
    foreach b [split $sel] {
        if {$b eq "" || $b eq ">"} continue
        lappend bits $b
    }
    if {[llength $bits] == 0} { return 0 }
    if {![sunCompoundMatch [lindex $bits end] $tag $classes $id]} { return 0 }
    if {[llength $bits] == 1} { return 1 }
    set need [lrange $bits 0 end-1]
    set ai [expr {[llength $::cssAnc] - 1}]
    set ni [expr {[llength $need] - 1}]
    while {$ni >= 0 && $ai >= 0} {
        set anc [lindex $::cssAnc $ai]
        if {[sunCompoundMatch [lindex $need $ni] [lindex $anc 0] [lindex $anc 1] [lindex $anc 2]]} {
            incr ni -1
        }
        incr ai -1
    }
    return [expr {$ni < 0}]
}
proc sunComputeStyle {tag classes id inline} {
    set merged [dict create]
    foreach rule $::sunCss {
        lassign $rule sels props
        foreach sel [split $sels ","] {
            set one [string trim $sel]
            if {[string match {*\[*} $one] || [string match {*+*} $one] || [string match {*~*} $one]} continue
            if {[sunSelectorMatch $one $tag $classes $id]} {
                set merged [dict merge $merged $props]
                break
            }
        }
    }
    if {$inline ne ""} { set merged [dict merge $merged [sunCssBody $inline]] }
    if {[llength $::cssAnc] > 0} {
        set parent [lindex [lindex $::cssAnc end] 3]
        if {![dict exists $merged align] && [dict exists $parent align]} {
            dict set merged align [dict get $parent align]
        }
        if {![dict exists $merged fg] && [dict exists $parent fg]} {
            dict set merged fg [dict get $parent fg]
        }
        if {![dict exists $merged bg] && [dict exists $parent bg]} {
            dict set merged bg [dict get $parent bg]
        }
    }
    return $merged
}
proc sunActiveStyle {} {
    if {![info exists ::cssAnc] || [llength $::cssAnc] == 0} { return [dict create] }
    return [lindex [lindex $::cssAnc end] 3]
}
proc sunOpen {raw name} {
    set classes {}
    set id ""
    set inline ""
    set classattr ""
    regexp -nocase {class\s*=\s*["']([^"']*)["']} $raw -> classattr
    if {$classattr ne ""} { set classes [split $classattr] }
    regexp -nocase {\sid\s*=\s*["']([^"']+)["']} $raw -> id
    regexp -nocase {style\s*=\s*["']([^"']*)["']} $raw -> inline
    set style [sunComputeStyle $name $classes $id $inline]
    if {[dict exists $style hide]} { incr ::cssHide }
    lappend ::cssAnc [list $name $classes $id $style]
}
proc sunCloseTag {} {
    if {![info exists ::cssAnc] || [llength $::cssAnc] == 0} return
    set top [lindex $::cssAnc end]
    set ::cssAnc [lrange $::cssAnc 0 end-1]
    if {[dict exists [lindex $top 3] hide] && $::cssHide > 0} { incr ::cssHide -1 }
}
proc sunStyleTag {t st} {
    set fg ""; set bg ""; set align ""; set bold 0; set size 0
    if {[dict exists $st fg]} { set fg [dict get $st fg] }
    if {[dict exists $st bg]} { set bg [dict get $st bg] }
    if {[dict exists $st align]} { set align [dict get $st align] }
    if {[dict exists $st bold]} { set bold [dict get $st bold] }
    if {[dict exists $st size]} { set size [dict get $st size] }
    if {$fg eq "" && $bg eq "" && $align eq "" && !$bold && $size == 0} { return "" }
    set key "$fg|$bg|$align|$bold|$size"
    if {[info exists ::styTag($t,$key)]} { return $::styTag($t,$key) }
    if {![info exists ::styN]} { set ::styN 0 }
    incr ::styN
    set tn sty$::styN
    set opts {}
    if {$fg ne ""} { lappend opts -foreground $fg }
    if {$bg ne ""} { lappend opts -background $bg }
    if {$align ne ""} { lappend opts -justify $align }
    if {$bold || $size > 0} {
        set sz 12
        if {$size >= 22} { set sz 18 } elseif {$size >= 16} { set sz 14 } elseif {$size > 0 && $size < 11} { set sz 10 }
        set weight normal
        if {$bold} { set weight bold }
        set fn sunfont$::styN
        catch {font delete $fn}
        font create $fn -family "DejaVu Sans" -size $sz -weight $weight
        lappend opts -font $fn
    }
    $t tag configure $tn {*}$opts
    set ::styTag($t,$key) $tn
    return $tn
}
proc sunWalk {t html base} {
    set ::cssAnc {}
    set ::cssHide 0
    set ::sunCss {}
    sunGatherCss $html $base
    sunApplyPageChrome $t
    regsub -all {(?s)<!--.*?-->} $html "" html
    regsub -all -nocase {<script[^>]*>} $html "\x01" html
    regsub -all -nocase {</script>} $html "\x02" html
    regsub -all -nocase {<style[^>]*>} $html "\x01" html
    regsub -all -nocase {</style>} $html "\x02" html
    set skip 0
    set link ""
    set ::curForm ""
    if {![info exists ::formSeq]} { set ::formSeq 0 }
    set i 0
    set n [string length $html]
    while {$i < $n} {
        set cut [string first \x01 $html $i]
        set back [string first \x02 $html $i]
        if {$skip} {
            if {$back < 0} break
            set skip 0
            set i [expr {$back + 1}]
            continue
        }
        if {$cut >= 0 && ($back < 0 || $cut < $back)} {
            set lt [string first < $html $i]
            if {$lt < 0 || $cut < $lt} {
                if {$cut > $i} { sunPut $t [string range $html $i [expr {$cut - 1}]] $link }
                set skip 1
                set i [expr {$cut + 1}]
                continue
            }
        }
        set lt [string first < $html $i]
        if {$lt < 0} {
            sunPut $t [string range $html $i end] $link
            break
        }
        if {$lt > $i} { sunPut $t [string range $html $i [expr {$lt - 1}]] $link }
        set gt [string first > $html $lt]
        if {$gt < 0} break
        set raw [string range $html [expr {$lt + 1}] [expr {$gt - 1}]]
        set i [expr {$gt + 1}]
        if {[string match "!--*" $raw]} continue
        set closed 0
        if {[string match "/*" $raw]} {
            set closed 1
            set raw [string range $raw 1 end]
        }
        if {[string match "*/" $raw]} { set raw [string trimright $raw /] }
        set name [string tolower [lindex [split [string trim $raw] " \t\r\n"] 0]]
        set name [string trim $name "\"'/"]
        if {$name eq ""} continue
        if {$closed} {
            if {$name eq "a" && $::cssHide == 0} {
                set ch ""
                catch {set ch [$t get "end-2c" "end-1c"]}
                if {$ch ni {"" " " "\n"}} { $t insert end " " }
            }
            sunCloseTag
            if {$name eq "a"} { set link "" }
            if {$name eq "form"} { set ::curForm "" }
            continue
        }
        sunOpen $raw $name
        if {$name eq "br"} {
            if {$::cssHide == 0} { $t insert end "\n" }
            sunCloseTag
            continue
        }
        if {$::cssHide > 0 && $name ne "input"} {
            if {$name in {img meta link hr area base col embed source wbr}} { sunCloseTag }
            continue
        }
        switch -- $name {
            p - div - section - article - header - footer - tr - ul - ol - li - h1 - h2 - h3 - table {
                sunEnsureNl $t
            }
        }
        if {$name eq "h1" || $name eq "h2"} {
            set mark [$t index end-1c]
            set ::block($t) $name
            set ::blockAt($t) $mark
        }
        if {$name eq "a" && [regexp -nocase {href\s*=\s*["']([^"']+)["']} $raw -> href]} {
            set abs [sunResolve $base $href]
            if {$abs ne ""} { set link $abs }
        } elseif {$name eq "a" && [regexp -nocase {href\s*=\s*([^\s>]+)} $raw -> href]} {
            set abs [sunResolve $base $href]
            if {$abs ne ""} { set link $abs }
        }
        if {$name eq "img" && [regexp -nocase {src\s*=\s*["']([^"']+)["']} $raw -> src]} {
            sunImage $t [sunResolve $base $src]
        }
        if {$name eq "form"} {
            incr ::formSeq
            set fid f$::formSeq
            set ::curForm $fid
            set action $base
            if {[regexp -nocase {action\s*=\s*["']([^"']+)["']} $raw -> a]} {
                set abs [sunResolve $base $a]
                if {$abs ne ""} { set action $abs }
            }
            set ::faction($fid) $action
            set ::fmethod($fid) get
            if {[regexp -nocase {method\s*=\s*["']?post} $raw]} { set ::fmethod($fid) post }
            set ::ffields($fid) {}
            sunEnsureNl $t
        }
        if {$name eq "input" && $::curForm ne "" && ($::cssHide == 0 || [regexp -nocase {type\s*=\s*["']?hidden} $raw])} {
            sunFormInput $t $::curForm $raw
        }
        if {$name eq "li" && $::cssHide == 0} { $t insert end "  •  " }
        if {$name in {img input meta link hr area base col embed source wbr}} { sunCloseTag }
    }
}
proc sunPut {t chunk link} {
    if {[info exists ::cssHide] && $::cssHide > 0} return
    set chunk [sunDecode $chunk]
    if {$chunk eq ""} return
    set start [$t index end-1c]
    $t insert end $chunk
    set end [$t index end-1c]
    set st [sunActiveStyle]
    set sty [sunStyleTag $t $st]
    if {$sty ne ""} { $t tag add $sty $start $end }
    if {[info exists ::block($t)]} {
        $t tag add $::block($t) $::blockAt($t) $end
        unset ::block($t)
    } else {
        $t tag add p $start $end
    }
    if {$link ne ""} {
        incr ::linkn
        set tag L$::linkn
        set ::href($tag) $link
        $t tag add link $start $end
        $t tag add $tag $start $end
        if {![dict exists $st fg]} { $t tag add linkfg $start $end }
        $t tag raise linkfg
    }
}
proc sunImage {t url} {
    if {$url eq ""} return
    if {![regexp -nocase {\.(png|gif)($|\?)} $url]} return
    if {$::imgn >= 6} return
    incr ::imgn
    set n $::imgn
    set tmp /tmp/sunimg$n
    sunEnsureNl $t
    set mark m$n
    $t mark set $mark [$t index end-1c]
    $t mark gravity $mark left
    $t insert end "\n"
    if {[catch {open [list | curl -4 -sS -L --max-time 8 --dns-servers 1.1.1.1,8.8.8.8,77.88.8.8 --max-filesize 700000 -o $tmp -- $url] r} pipe]} return
    fconfigure $pipe -blocking 0
    fileevent $pipe readable [list sunImageDone $t $mark $tmp $pipe $n]
}
proc sunImageDone {t mark tmp pipe n} {
    if {[catch {eof $pipe} done]} {
        catch { close $pipe }
        return
    }
    if {!$done} { catch { read $pipe }; return }
    catch { fileevent $pipe readable {} }
    catch { fconfigure $pipe -blocking 1 }
    catch { close $pipe }
    if {![winfo exists $t]} return
    if {[catch {$t index $mark}]} return
    catch {image delete sunimg$n}
    if {[catch {image create photo sunimg$n -file $tmp} img]} return
    $t image create $mark -image $img
}
proc sunDrain {pipe} {
    if {[catch {eof $pipe} done] || $done} {
        catch { fileevent $pipe readable {} }
        catch { close $pipe }
        if {[info exists ::sunEnginePipe] && $::sunEnginePipe eq $pipe} { unset ::sunEnginePipe }
        return
    }
    catch { read $pipe }
}
proc sunEngineStop {} {
    if {[info exists ::sunGrab]} {
        after cancel $::sunGrab
        unset ::sunGrab
    }
    unset -nocomplain ::sunPendingUrl
    if {[info exists ::sunXid] && $::sunXid ne ""} {
        catch {exec xdotool windowkill $::sunXid}
        catch {exec xdotool windowunmap $::sunXid}
    }
    if {[info exists ::sunEnginePipe]} {
        set p $::sunEnginePipe
        unset ::sunEnginePipe
        catch { fileevent $p readable {} }
        set kids [pid $p]
        foreach k $kids {
            catch { exec kill -TERM $k }
        }
        after 80
        foreach k $kids {
            catch { exec kill -KILL $k }
        }
        catch { fconfigure $p -blocking 0 }
        catch { close $p }
    }
    catch {exec sh -c {for p in $(pidof netsurf netsurf-gtk nsgtk 2>/dev/null); do kill -TERM $p 2>/dev/null; done; sleep 0.1; for p in $(pidof netsurf netsurf-gtk nsgtk 2>/dev/null); do kill -KILL $p 2>/dev/null; done}}
    set ::sunXid ""
    set ::sunEngineUrl ""
}
proc sunEngineGo {url} {
    set b .wbrowse.in.b
    if {![winfo exists $b.host]} return
    foreach t $::sunTabs {
        if {[winfo exists $b.view.$t]} { pack forget $b.view.$t }
    }
    pack $b.host -in $b.view -fill both -expand 1
    $b.host.wait configure -text "Открываю страницу…"
    update idletasks
    if {[info exists ::sunEngineUrl] && $::sunEngineUrl eq $url && [info exists ::sunXid] && $::sunXid ne ""} {
        sunEngineFit
        sunStatus "Готово"
        if {![info exists ::sunGrab]} { set ::sunGrab [after 300 sunEngineGrab] }
        return
    }
    set ::sunPendingUrl $url
    sunEngineStop
    set ::sunPendingUrl $url
    set ::sunGrab [after 300 [list sunEngineStart $url]]
}
proc sunEngineStart {url} {
    if {![info exists ::sunPendingUrl] || $::sunPendingUrl ne $url} return
    if {![winfo exists .wbrowse.in.b.host]} return
    set ::sunEngineUrl $url
    set q [string map {' '\\''} $url]
    if {[catch {open [list | /bin/sh -c "GDK_BACKEND=x11 netsurf '$q' >>/tmp/netsurf.log 2>&1"] r} pipe]} {
        sunStatus "Движок страницы не запустился"
        return
    }
    fconfigure $pipe -blocking 0
    set ::sunEnginePipe $pipe
    fileevent $pipe readable [list sunDrain $pipe]
    set ::sunEngineTries 0
    set ::sunGrab [after 700 sunEngineGrab]
}
proc sunPickNetSurf {} {
    set best ""
    set bestA 0
    foreach class {NetSurf netsurf} {
        if {[catch {exec xdotool search --class $class} out]} continue
        foreach id [split $out \n] {
            set id [string trim $id]
            if {![string is integer -strict $id]} continue
            if {[catch {exec xdotool getwindowgeometry $id} geo]} continue
            if {![regexp {Geometry: ([0-9]+)x([0-9]+)} $geo -> w h]} continue
            set area [expr {$w * $h}]
            if {$area > $bestA} {
                set bestA $area
                set best $id
            }
        }
    }
    return $best
}
proc sunEngineGrab {} {
    set parent .wbrowse.in.b.host
    if {![winfo exists $parent]} { return }
    if {![info exists ::sunEngineUrl] || $::sunEngineUrl eq ""} { return }
    set found {}
    if {[winfo exists .wbrowse] && [winfo viewable .wbrowse]} {
        foreach wid [xwinFor {NetSurf netsurf Netsurf netsurf-gtk nsgtk} {netsurf netsurf-gtk}] {
            set geo [xwinScreen $wid]
            if {[llength $geo] != 4} continue
            lassign $geo sx sy w h
            if {$w < 320 || $h < 200} continue
            lappend found $wid
        }
    }
    set best ""
    if {[llength $found] > 0} { set best [lindex [lsort -integer $found] end] }
    if {$best eq ""} {
        if {![info exists ::sunEngineTries]} { set ::sunEngineTries 0 }
        incr ::sunEngineTries
        if {$::sunEngineTries == 40} { sunStatus "Страница не появилась" }
    } else {
        set ::sunXid $best
        if {[winfo exists $parent.wait]} { place forget $parent.wait }
        foreach wid [lsort -integer $found] { embedSync $wid $parent }
        sunStatus "Готово"
    }
    if {[winfo exists $parent] && [info exists ::sunEngineUrl] && $::sunEngineUrl ne ""} {
        set ::sunGrab [after 300 sunEngineGrab]
    }
}
proc sunEngineFit {} {
    if {![info exists ::sunXid] || $::sunXid eq ""} return
    if {![winfo exists .wbrowse.in.b.host]} return
    set w [winfo width .wbrowse.in.b.host]
    set h [winfo height .wbrowse.in.b.host]
    if {$w < 40 || $h < 40} return
    catch {exec xdotool windowmove $::sunXid 0 0}
    catch {exec xdotool windowsize --sync $::sunXid $w $h}
}
proc sunRenderFail {id url err} {
    set safe [string map {& &amp; < &lt;} $err]
    sunRenderPage $id $url "<h1>Страница не открылась</h1><p>$url</p><p>$safe</p><p><a href=\"about:home\">На главную</a></p>"
    sunStatus "Ошибка"
}
proc sunLoad {id url {post ""}} {
    set ::loc($id) $url
    if {$::sunCur eq $id && [winfo exists .wbrowse.in.b.bar.url]} {
        .wbrowse.in.b.bar.url delete 0 end
        .wbrowse.in.b.bar.url insert 0 $url
    }
    if {$url eq "about:home"} {
        sunEngineStop
        sunStop $id
        if {![info exists ::sunGen($id)]} { set ::sunGen($id) 0 }
        incr ::sunGen($id)
        if {[winfo exists .wbrowse.in.b.host]} { pack forget .wbrowse.in.b.host }
        if {[winfo exists .wbrowse.in.b.view.$id]} {
            pack .wbrowse.in.b.view.$id -fill both -expand 1
        }
        sunRenderPage $id $url [sunHome]
        return
    }
    if {[regexp {^https?://} $url] && $post eq ""} {
        sunStop $id
        sunEngineGo $url
        return
    }
    sunStatus "Загрузка $url"
    sunStop $id
    if {![info exists ::sunGen($id)]} { set ::sunGen($id) 0 }
    incr ::sunGen($id)
    set gen $::sunGen($id)
    set tmp /tmp/sun-$id.html
    set ::sunFile($id) $tmp
    set ::sunOut($id) ""
    set args [list curl -4 -sS -L --max-time 20 --dns-servers 1.1.1.1,8.8.8.8,77.88.8.8 -A SunBrowser/1.0 -o $tmp -w %{url_effective}]
    if {$post ne ""} { lappend args --data-raw $post }
    lappend args -- $url
    if {[catch {open [concat [list |] $args] r} pipe]} {
        sunRenderFail $id $url $pipe
        return
    }
    fconfigure $pipe -blocking 0
    set ::sunPipe($id) $pipe
    fileevent $pipe readable [list sunPipe $id $url $pipe $gen]
}
proc sunPipe {id url pipe gen} {
    if {![info exists ::sunGen($id)] || $::sunGen($id) != $gen} {
        catch { fileevent $pipe readable {} }
        catch { close $pipe }
        return
    }
    if {[catch {read $pipe} chunk]} {
        catch { fileevent $pipe readable {} }
        catch { close $pipe }
        unset -nocomplain ::sunPipe($id)
        return
    }
    append ::sunOut($id) $chunk
    if {[catch {eof $pipe} done] || !$done} return
    catch { fileevent $pipe readable {} }
    catch { fconfigure $pipe -blocking 1 }
    set code [catch {close $pipe} err]
    unset -nocomplain ::sunPipe($id)
    set final [string trim $::sunOut($id)]
    if {[regexp {^(https?://\S+)} $final -> got]} { set url $got }
    if {![winfo exists .wbrowse] || [lsearch -exact $::sunTabs $id] < 0} return
    if {$code || ![file exists $::sunFile($id)] || [file size $::sunFile($id)] == 0} {
        sunRenderFail $id $url $err
        return
    }
    if {[catch {
        set fh [open $::sunFile($id) r]
        fconfigure $fh -encoding utf-8
        set html [read $fh 500000]
        close $fh
    } readErr]} {
        sunRenderFail $id $url $readErr
        return
    }
    sunRenderPage $id $url $html
}

proc openAbout {} {
    set w [newWindow about "Система" 560 420]
    set b $w.in.b
    if {[winfo exists $b.k]} { return }
    set info [sysinfo]
    label $b.k -text $::host -bg $::MICA -fg $::WHITE -font title -anchor w
    pack $b.k -fill x -padx 22 -pady {6 2}
    label $b.e -text [lindex $info 3] -bg $::MICA -fg $::GRAY -font small -anchor w
    pack $b.e -fill x -padx 22 -pady {0 10}
    foreach {cap val} [list \
        "система" [lindex $info 3] \
        "ядро" [lindex $info 0] \
        "память" [lindex $info 1] \
        "сеть" [lindex $info 2] \
        "сеанс" "$::user@$::host"] {
        frame $b.r$cap -bg $::CARD
        pack $b.r$cap -fill x -padx 22 -pady 4
        label $b.r$cap.c -text $cap -bg $::CARD -fg $::ACCENT -font small -width 10 -anchor w
        label $b.r$cap.v -text $val -bg $::CARD -fg $::WHITE -font small -anchor w -wraplength 340 -justify left
        pack $b.r$cap.c -side left -padx 12 -pady 8
        pack $b.r$cap.v -side left -fill x -expand 1 -pady 8
    }
}

proc chip {parent name text var value} {
    label $parent.$name -text $text -bg $::CARD -fg $::WHITE -font small -padx 12 -pady 8 -cursor hand2
    pack $parent.$name -side left -padx 4 -pady 4
    bind $parent.$name <Button-1> [list pickChip $parent $var $value]
    set ::chipw($parent.$name) [list $var $value]
}
proc pickChip {parent var value} {
    set $var $value
    paintChips $parent
}
proc paintChips {parent} {
    foreach w [winfo children $parent] {
        if {![info exists ::chipw($w)]} continue
        lassign $::chipw($w) var value
        if {[set $var] eq $value} {
            $w configure -bg $::ACCENT -fg $::INK
        } else {
            $w configure -bg $::CARD -fg $::WHITE
        }
    }
}

proc settingsLoad {} {
    set ::set_res 1920x1080
    set ::set_lang ru
    set ::set_kb us,ru
    set ::set_font 12
    set ::set_vol 70
    set ::set_theme sand
    set ::set_wall sand
    set ::set_wallfile ""
    set ::set_h24 24
    set ::set_tz Europe/Samara
    set ::set_date dmy
    set ::set_fontfam dejavu
    set ::set_anim normal
    set ::set_sound off
    set ::set_csize 16
    set ::set_ccolor #ffffff
    set ::set_speak 0
    set ::set_trashboot 0
    set ::set_termbg #0c0c0c
    set ::set_termfg #cccccc
    set ::set_termstyle dark
    set conf /root/.deepos/settings
    if {![file exists $conf]} { tzApply; return }
    set fh [open $conf r]
    while {[gets $fh line] >= 0} {
        if {[regexp {^RESOLUTION=(.+)$} $line -> v]} { set ::set_res $v }
        if {[regexp {^UI_LANG=(.+)$} $line -> v]} { set ::set_lang $v }
        if {[regexp {^KEYBOARD=(.+)$} $line -> v]} { set ::set_kb $v }
        if {[regexp {^FONT_SIZE=(.+)$} $line -> v]} { set ::set_font $v }
        if {[regexp {^VOLUME=(.+)$} $line -> v]} { set ::set_vol $v }
        if {[regexp {^HOSTNAME=(.+)$} $line -> v]} { set ::set_host $v }
        if {[regexp {^THEME=(.+)$} $line -> v]} { set ::set_theme $v }
        if {[regexp {^WALL=(.+)$} $line -> v]} { set ::set_wall $v }
        if {[regexp {^WALLFILE=(.+)$} $line -> v]} { set ::set_wallfile $v }
        if {[regexp {^CLOCK_H24=(.+)$} $line -> v]} { set ::set_h24 $v }
        if {[regexp {^TZ=(.+)$} $line -> v]} { set ::set_tz $v }
        if {[regexp {^DATE_FMT=(.+)$} $line -> v]} { set ::set_date $v }
        if {[regexp {^FONT_FAMILY=(.+)$} $line -> v]} { set ::set_fontfam $v }
        if {[regexp {^ANIM=(.+)$} $line -> v]} { set ::set_anim $v }
        if {[regexp {^SOUND=(.+)$} $line -> v]} { set ::set_sound $v }
        if {[regexp {^CURSOR_SIZE=(.+)$} $line -> v]} { set ::set_csize $v }
        if {[regexp {^CURSOR_COLOR=(.+)$} $line -> v]} {
            set v [string trim $v "\"'"]
            if {![string match #* $v]} { set v #$v }
            set ::set_ccolor $v
        }
        if {[regexp {^SPEAK=(.+)$} $line -> v]} { set ::set_speak $v }
        if {[regexp {^TRASH_BOOT=(.+)$} $line -> v]} { set ::set_trashboot $v }
        if {[regexp {^TERM_BG=(.+)$} $line -> v]} {
            set v [string trim $v "\"'"]
            if {![string match #* $v]} { set v #$v }
            set ::set_termbg $v
        }
        if {[regexp {^TERM_FG=(.+)$} $line -> v]} {
            set v [string trim $v "\"'"]
            if {![string match #* $v]} { set v #$v }
            set ::set_termfg $v
        }
        if {[regexp {^TERM_STYLE=(.+)$} $line -> v]} { set ::set_termstyle $v }
    }
    close $fh
    if {[info exists ::set_host] && $::set_host ne ""} { set ::host $::set_host }
    tzApply
}
proc settingsFacts {} {
    set up 0
    set addr ""
    set iface ""
    set raw [sh "ip -4 -o addr show scope global 2>/dev/null"]
    if {[regexp {(\S+)\s+inet ([0-9.]+)} $raw -> iface addr]} { set up 1 }
    set gw ""
    set route [sh "ip -4 route show default 2>/dev/null"]
    regexp {default via ([0-9.]+)} $route -> gw
    set dns {}
    foreach line [split [readFile /etc/resolv.conf 800] \n] {
        if {[regexp {^nameserver\s+(\S+)} $line -> ns]} { lappend dns $ns }
    }
    set rel [string trim [sh "uname -r"]]
    set pretty "DeepOS"
    foreach line [split [readFile /etc/os-release 1500] \n] {
        if {[string match PRETTY_NAME=* $line]} {
            set pretty [string trim [string range $line 12 end] \"]
        }
    }
    set access "Обычный"
    if {$::set_font >= 14} { set access "Крупный" }
    set netlabel "Нет сети"
    if {$up} { set netlabel "Подключено" }
    return [dict create up $up addr $addr iface $iface gw $gw dns [join $dns ", "] \
        rel $rel pretty $pretty access $access netlabel $netlabel]
}
proc openSettings {{page ""}} {
    set w [newWindow settings "Настройки" 1180 900]
    set b $w.in.b
    settingsLoad
    if {$page eq ""} {
        if {![info exists ::setPage]} { set ::setPage home }
    } else {
        set ::setPage $page
    }
    if {[winfo exists $b.nav]} {
        settingsShow $::setPage
        return
    }
    $b configure -bg #1f1f1f
    frame $b.nav -bg #191919 -width 250
    pack $b.nav -side left -fill y
    pack propagate $b.nav 0
    frame $b.nav.who -bg #191919 -height 64
    pack $b.nav.who -fill x -padx 12 -pady {14 6}
    pack propagate $b.nav.who 0
    canvas $b.nav.who.av -width 36 -height 36 -bg #191919 -highlightthickness 0
    pack $b.nav.who.av -side left
    $b.nav.who.av create oval 2 2 34 34 -fill #e4c4a0 -outline {}
    $b.nav.who.av create text 18 18 -text "R" -fill #1c1612 -font taskb
    label $b.nav.who.n -text $::user -bg #191919 -fg #ffffff -font ui -anchor w
    label $b.nav.who.m -text "$::user@$::host" -bg #191919 -fg #9a9a9a -font tiny -anchor w
    pack $b.nav.who.n -anchor w -padx 10
    pack $b.nav.who.m -anchor w -padx 10
    accountPaintWho
    foreach {id label} {
        home "Главная"
        account "Учётная запись"
        perm "Разрешения"
        system "Система"
        net "Сеть и Интернет"
        personal "Персонализация"
        apps "Приложения"
        time "Время и язык"
        access "Специальные возможности"
        updates "Центр обновления"
    } {
        settingsNav $id $label
    }
    frame $b.main -bg #1f1f1f
    pack $b.main -side left -fill both -expand 1
    frame $b.main.find -bg #2a2a2a -height 40 \
        -highlightthickness 1 -highlightbackground #3a3a3a -highlightcolor #e4c4a0
    pack $b.main.find -fill x -padx 28 -pady {16 0}
    pack propagate $b.main.find 0
    entry $b.main.find.e -bg #2a2a2a -fg #ffffff -insertbackground #e4c4a0 -font ui \
        -bd 0 -highlightthickness 0 -relief flat
    pack $b.main.find.e -fill both -expand 1 -padx 14
    label $b.main.find.ph -text "Найти параметр" -bg #2a2a2a -fg #8a8a8a -font ui
    place $b.main.find.ph -in $b.main.find -x 16 -rely 0.5 -anchor w
    bind $b.main.find.e <KeyRelease> settingsType
    bind $b.main.find.ph <Button-1> { focus .wsettings.in.b.main.find.e }
    label $b.main.st -text [settingsKeepText] -bg #1f1f1f -fg #8a8a8a -font small -anchor w
    pack $b.main.st -side bottom -fill x -padx 28 -pady 8
    canvas $b.scroll -bg #1f1f1f -highlightthickness 0 -bd 0
    frame $b.page -bg #1f1f1f
    pack $b.scroll -in $b.main -fill both -expand 1
    $b.scroll create window 0 0 -anchor nw -window $b.page -tag body
    bind $b.scroll <Configure> settingsFit
    bind $b.page <Configure> settingsFit
    bind $b.scroll <Button-4> { %W yview scroll -4 units }
    bind $b.scroll <Button-5> { %W yview scroll 4 units }
    settingsShow $::setPage
}
proc settingsFit {} {
    if {[info exists ::setFit]} return
    set c .wsettings.in.b.scroll
    set p .wsettings.in.b.page
    if {![winfo exists $c] || ![winfo exists $p]} return
    set ::setFit 1
    update idletasks
    set w [winfo width $c]
    if {$w < 80} { set w 760 }
    $c itemconfigure body -width $w
    set h [winfo reqheight $p]
    if {$h < 40} { set h 40 }
    $c configure -scrollregion [list 0 0 $w $h]
    settingsWheel $p
    unset ::setFit
}
proc settingsWheel {w} {
    if {![winfo exists $w]} return
    set cls [winfo class $w]
    if {$cls ne "Text" && $cls ne "Canvas" && $cls ne "Entry" && $cls ne "Scale"} {
        bind $w <Button-4> { .wsettings.in.b.scroll yview scroll -4 units }
        bind $w <Button-5> { .wsettings.in.b.scroll yview scroll 4 units }
    }
    foreach child [winfo children $w] { settingsWheel $child }
}
proc settingsKeepText {} {
    if {[file exists /persist/deepos]} {
        return "Сохраняется на диск и остаётся после перезагрузки."
    }
    return "Диск состояния не подключён: держится до выключения."
}
proc navGlyph {c id} {
    $c delete all
    set fg #e8e8e8
    switch -- $id {
        home {
            $c create polygon 11 4 18 11 16 11 16 18 6 18 6 11 4 11 -outline $fg -fill {} -width 1
        }
        account {
            $c create oval 7 3 15 11 -outline $fg -width 1
            $c create arc 3 12 19 24 -start 0 -extent 180 -style arc -outline $fg -width 1
        }
        perm {
            $c create rectangle 4 9 18 18 -outline $fg -width 1
            $c create arc 7 4 15 12 -start 0 -extent 180 -style arc -outline $fg -width 1
        }
        system {
            $c create oval 8 8 14 14 -outline $fg -width 1
            $c create line 11 3 11 6 -fill $fg
            $c create line 11 16 11 19 -fill $fg
            $c create line 3 11 6 11 -fill $fg
            $c create line 16 11 19 11 -fill $fg
        }
        net {
            $c create oval 3 4 19 18 -outline $fg -width 1
            $c create oval 7 4 15 18 -outline $fg -width 1
            $c create line 3 11 19 11 -fill $fg
        }
        personal {
            $c create rectangle 3 6 11 14 -fill #e4c4a0 -outline {}
            $c create rectangle 9 9 18 17 -fill #7eb6ff -outline {}
        }
        apps {
            foreach {a b} {4 4 12 4 4 12 12 12} {
                $c create rectangle $a $b [expr {$a + 6}] [expr {$b + 6}] -fill #7eb6ff -outline {}
            }
        }
        time {
            $c create oval 3 3 19 19 -outline $fg -width 1
            $c create line 11 11 11 6 -fill $fg
            $c create line 11 11 15 13 -fill $fg
        }
        access {
            $c create text 11 12 -text "A" -fill $fg -font taskb
        }
        updates {
            $c create arc 4 4 18 18 -start 30 -extent 280 -style arc -outline $fg -width 1
            $c create polygon 15 3 19 6 14 8 -fill $fg -outline {}
        }
    }
}
proc settingsNav {id label} {
    set f .wsettings.in.b.nav.$id
    frame $f -bg #1c1c1c -height 42 -cursor hand2
    pack $f -fill x -padx 8 -pady 1
    pack propagate $f 0
    frame $f.mark -bg #1c1c1c -width 3
    pack $f.mark -side left -fill y
    canvas $f.ic -width 22 -height 22 -bg #1c1c1c -highlightthickness 0
    pack $f.ic -side left -padx {8 0}
    navGlyph $f.ic $id
    label $f.t -text $label -bg #1c1c1c -fg #f6f1ea -font ui -anchor w -cursor hand2
    pack $f.t -side left -fill both -expand 1 -padx 10
    foreach w [list $f $f.t $f.mark $f.ic] {
        bind $w <Button-1> [list settingsShow $id]
        bind $w <Enter> [list settingsNavHover $id 1]
        bind $w <Leave> [list settingsNavHover $id 0]
    }
}
proc settingsNavPaint {id bg mark} {
    set f .wsettings.in.b.nav.$id
    if {![winfo exists $f]} return
    $f configure -bg $bg
    $f.t configure -bg $bg
    $f.mark configure -bg $mark
    if {[winfo exists $f.ic]} { $f.ic configure -bg $bg }
}
proc settingsNavHover {id on} {
    if {$id eq $::setPage} return
    set bg #1c1c1c
    if {$on} { set bg #2a241e }
    settingsNavPaint $id $bg $bg
}
proc settingsMark {} {
    foreach id {home system net personal apps time access updates} {
        if {$id eq $::setPage} {
            settingsNavPaint $id #2a241e $::ACCENT
        } else {
            settingsNavPaint $id #1c1c1c #1c1c1c
        }
    }
}
proc settingsShow {id} {
    set ::setPage $id
    settingsMark
    set p .wsettings.in.b.page
    foreach c [winfo children $p] { destroy $c }
    switch -- $id {
        home { settingsHome }
        account { settingsAccount }
        perm { settingsPerm }
        system { settingsSystem }
        net { settingsNet }
        personal { settingsPersonal }
        apps { settingsApps }
        time { settingsTime }
        access { settingsAccess }
        updates { settingsUpdates }
        sound { settingsSound }
        screen { settingsScreen }
        kb { settingsKb }
        lang { settingsLang }
        power { settingsPower }
        about { settingsAbout }
    }
    settingsFit
}
proc settingsType {} {
    set e .wsettings.in.b.main.find.e
    set ph .wsettings.in.b.main.find.ph
    if {![winfo exists $e]} return
    set q [string trim [$e get]]
    if {$q eq ""} {
        if {[winfo exists $ph]} { place $ph -in .wsettings.in.b.main.find -x 16 -rely 0.5 -anchor w }
        if {[info exists ::setSearching] && $::setSearching} {
            set ::setSearching 0
            settingsShow home
        }
        return
    }
    if {[winfo exists $ph]} { place forget $ph }
    set ::setSearching 1
    settingsResults $q
}
proc settingsResults {q} {
    set p .wsettings.in.b.page
    if {![winfo exists $p]} return
    foreach c [winfo children $p] { destroy $c }
    set needle [string tolower $q]
    set hits {}
    foreach {id title words} {
        sound Звук {громкость звук}
        net {Сеть и Интернет} {сеть ip dns интернет}
        screen Экран {экран разрешение персонализация}
        kb Клавиатура {клавиатура раскладка мышь}
        lang Язык {язык время}
        access {Специальные возможности} {шрифт доступность текст}
        power Питание {питание сон выключение}
        about {О системе} {система ядро память}
        apps Приложения {приложения программы пакеты}
        updates {Центр обновления} {обновления пакеты}
    } {
        set blob [string tolower "$title $words"]
        if {[string match *$needle* $blob]} { lappend hits $id $title }
    }
    label $p.h -text "Результаты" -bg #1f1f1f -fg #ffffff -font title -anchor w
    pack $p.h -fill x -padx 28 -pady {18 8}
    if {[llength $hits] == 0} {
        label $p.empty -text "Ничего не найдено" -bg #1f1f1f -fg #8a8a8a -font ui -anchor w
        pack $p.empty -fill x -padx 28
        return
    }
    foreach {id title} $hits {
        frame $p.r$id -bg #2d2d2d -height 48 -cursor hand2
        pack $p.r$id -fill x -padx 28 -pady 4
        pack propagate $p.r$id 0
        label $p.r$id.t -text $title -bg #2d2d2d -fg #ffffff -font ui -anchor w -cursor hand2
        pack $p.r$id.t -fill both -expand 1 -padx 16
        bind $p.r$id <Button-1> [list settingsOpenHit $id]
        bind $p.r$id.t <Button-1> [list settingsOpenHit $id]
    }
}
proc settingsOpenHit {id} {
    set e .wsettings.in.b.main.find.e
    if {[winfo exists $e]} { $e delete 0 end }
    set ::setSearching 0
    if {[winfo exists .wsettings.in.b.main.find.ph]} {
        place .wsettings.in.b.main.find.ph -in .wsettings.in.b.main.find -x 16 -rely 0.5 -anchor w
    }
    settingsShow $id
}
proc settingsHead {text} {
    set p .wsettings.in.b.page
    label $p.h -text $text -bg #1f1f1f -fg #ffffff -font title -anchor w
    pack $p.h -fill x -padx 28 -pady {22 8}
    return $p
}
proc settingsCard {parent col row title sub cmd {span 1} {tall 96}} {
    set f $parent.c${col}${row}
    frame $f -bg $::CARD -height $tall -cursor hand2
    grid $f -row $row -column $col -columnspan $span -padx 8 -pady 8 -sticky nsew
    pack propagate $f 0
    label $f.t -text $title -bg $::CARD -fg $::WHITE -font ui -anchor w -cursor hand2
    label $f.s -text $sub -bg $::CARD -fg $::GRAY -font small -anchor w -justify left -cursor hand2
    pack $f.t -fill x -padx 16 -pady {14 2}
    pack $f.s -fill x -padx 16
    foreach w [list $f $f.t $f.s] {
        bind $w <Button-1> $cmd
        bind $w <Enter> [list settingsCardHover $f 1]
        bind $w <Leave> [list settingsCardHover $f 0]
    }
}
proc settingsCardHover {f on} {
    if {![winfo exists $f]} return
    set bg $::CARD
    if {$on} { set bg #2e2823 }
    $f configure -bg $bg
    foreach w [winfo children $f] { $w configure -bg $bg }
}
proc settingsMemLine {} {
    set mt 0
    set ma 0
    set info [readFile /proc/meminfo 500]
    regexp {MemTotal:\s+(\d+)} $info -> mt
    regexp {MemAvailable:\s+(\d+)} $info -> ma
    if {$ma == 0} { regexp {MemFree:\s+(\d+)} $info -> ma }
    if {$mt <= 0} { return "—" }
    return [format "%.1f ГБ доступно из %.1f ГБ" [expr {$ma / 1048576.0}] [expr {$mt / 1048576.0}]]
}
proc settingsCpuLine {} {
    foreach line [split [readFile /proc/cpuinfo 2500] \n] {
        if {[regexp {^model name\s*:\s*(.+)$} $line -> cpu]} { return [string trim $cpu] }
    }
    set arch [string trim [sh "uname -m"]]
    if {$arch eq ""} { return "—" }
    return $arch
}
proc settingsPkgCount {} {
    set n 0
    if {![file exists /root/.deepos/world]} { return 0 }
    foreach line [split [readFile /root/.deepos/world 20000] \n] {
        if {[string trim $line] ne ""} { incr n }
    }
    return $n
}
proc settingsBox {parent name} {
    frame $parent.$name -bg #2d2d2d
    pack $parent.$name -fill x -pady 8
    return $parent.$name
}
proc settingsHome {} {
    set p .wsettings.in.b.page
    set d [settingsFacts]
    label $p.h -text "Главная" -bg #1f1f1f -fg #ffffff -font title -anchor w
    pack $p.h -fill x -padx 28 -pady {16 8}
    frame $p.hero -bg #1f1f1f
    pack $p.hero -fill x -padx 20
    frame $p.hero.dev -bg #2d2d2d -height 92 -cursor hand2
    pack $p.hero.dev -side left -fill both -expand 1 -padx 8
    pack propagate $p.hero.dev 0
    label $p.hero.dev.n -text $::host -bg #2d2d2d -fg #ffffff -font ui -anchor w
    label $p.hero.dev.k -text "Ядро [dict get $d rel]" -bg #2d2d2d -fg #bdbdbd -font small -anchor w
    label $p.hero.dev.r -text "Переименовать" -bg #2d2d2d -fg #e4c4a0 -font small -anchor w -cursor hand2
    pack $p.hero.dev.n -anchor w -padx 16 -pady {12 0}
    pack $p.hero.dev.k -anchor w -padx 16
    pack $p.hero.dev.r -anchor w -padx 16 -pady {2 0}
    bind $p.hero.dev.r <Button-1> settingsAskHost
    frame $p.hero.net -bg #2d2d2d -width 210 -height 92 -cursor hand2
    pack $p.hero.net -side left -padx 8
    pack propagate $p.hero.net 0
    label $p.hero.net.n -text [dict get $d iface] -bg #2d2d2d -fg #ffffff -font small -anchor w
    label $p.hero.net.s -text [dict get $d netlabel] -bg #2d2d2d -fg #bdbdbd -font tiny -anchor w
    pack $p.hero.net.n -anchor w -padx 14 -pady {22 0}
    pack $p.hero.net.s -anchor w -padx 14
    bind $p.hero.net <Button-1> {settingsShow net}
    bind $p.hero.net.n <Button-1> {settingsShow net}
    bind $p.hero.net.s <Button-1> {settingsShow net}
    if {[dict get $d iface] eq ""} { $p.hero.net.n configure -text "Нет сети" }
    frame $p.hero.up -bg #2d2d2d -width 230 -height 92 -cursor hand2
    pack $p.hero.up -side left -padx 8
    pack propagate $p.hero.up 0
    label $p.hero.up.n -text "Обновление" -bg #2d2d2d -fg #ffffff -font small -anchor w
    label $p.hero.up.s -text "Образ собирается на компьютере" -bg #2d2d2d -fg #bdbdbd -font tiny -anchor w -wraplength 200 -justify left
    pack $p.hero.up.n -anchor w -padx 14 -pady {18 0}
    pack $p.hero.up.s -anchor w -padx 14
    bind $p.hero.up <Button-1> {settingsShow updates}
    bind $p.hero.up.n <Button-1> {settingsShow updates}
    bind $p.hero.up.s <Button-1> {settingsShow updates}
    frame $p.cols -bg #1f1f1f
    pack $p.cols -fill both -expand 1 -padx 20 -pady 4
    frame $p.cols.l -bg #1f1f1f
    frame $p.cols.r -bg #1f1f1f
    pack $p.cols.l $p.cols.r -side left -fill both -expand 1 -padx 8
    set rec [settingsBox $p.cols.l rec]
    label $rec.t -text "Рекомендуемые параметры" -bg #2d2d2d -fg #ffffff -font ui -anchor w
    label $rec.s -text "То, что можно изменить сразу" -bg #2d2d2d -fg #9a9a9a -font tiny -anchor w
    pack $rec.t -fill x -padx 16 -pady {12 0}
    pack $rec.s -fill x -padx 16 -pady {0 6}
    settingsLink $rec sound "Звук" "$::set_vol%"
    settingsLink $rec apps "Установленные приложения" "[settingsPkgCount] дополнительно"
    settingsLink $rec kb "Клавиатура" $::set_kb
    set acc [settingsBox $p.cols.l acc]
    label $acc.t -text "Параметры специальных возможностей" -bg #2d2d2d -fg #ffffff -font ui -anchor w
    label $acc.s -text "Размер шрифта терминала" -bg #2d2d2d -fg #9a9a9a -font tiny -anchor w
    pack $acc.t -fill x -padx 16 -pady {12 0}
    pack $acc.s -fill x -padx 16
    frame $acc.row -bg #2d2d2d
    pack $acc.row -fill x -padx 12 -pady 10
    foreach {size text} {12 "По умолчанию" 14 "Средний" 16 "Крупный" 20 "Огромный"} {
        set on [expr {$::set_font == $size}]
        set bg #3a3a3a
        set fg #ffffff
        set bd 0
        if {$on} { set bg #3a3328; set fg #e4c4a0; set bd 1 }
        label $acc.row.f$size -text $text -bg $bg -fg $fg -font small -padx 10 -pady 10 -cursor hand2 \
            -highlightthickness $bd -highlightbackground #e4c4a0
        pack $acc.row.f$size -side left -padx 4
        bind $acc.row.f$size <Button-1> [list settingsFont $size]
    }
    set per [settingsBox $p.cols.r per]
    label $per.t -text "Персонализируйте устройство" -bg #2d2d2d -fg #ffffff -font ui -anchor w
    pack $per.t -fill x -padx 16 -pady {12 8}
    frame $per.row -bg #2d2d2d
    pack $per.row -fill x -padx 12
    foreach {res col} {1280x720 #243044 1600x900 #3a2a38 1920x1080 #1e3a32 1366x768 #3a3024} {
        canvas $per.row.c$res -width 96 -height 64 -bg #2d2d2d -highlightthickness 0 -cursor hand2
        pack $per.row.c$res -side left -padx 4
        set edge #3a3a3a
        if {$::set_res eq $res} { set edge #e4c4a0 }
        $per.row.c$res create rectangle 4 4 92 60 -fill $col -outline $edge -width 2
        $per.row.c$res create rectangle 4 50 92 60 -fill #111111 -outline {}
        $per.row.c$res create text 48 28 -text $res -fill #ffffff -font tiny
        bind $per.row.c$res <Button-1> [list settingsApplyRes $res]
    }
    frame $per.mode -bg #2d2d2d
    pack $per.mode -fill x -padx 16 -pady {10 0}
    label $per.mode.k -text "Цветовой режим" -bg #2d2d2d -fg #d0d0d0 -font small -anchor w
    label $per.mode.v -text [themeTitle] -bg #3a3a3a -fg #ffffff -font small -padx 12 -pady 6 -cursor hand2
    pack $per.mode.k -side left
    pack $per.mode.v -side right
    bind $per.mode.v <Button-1> {settingsShow personal}
    bind $per.mode.k <Button-1> {settingsShow personal}
    label $per.more -text "Экран и разрешение" -bg #2d2d2d -fg #e4c4a0 -font small -anchor w -cursor hand2
    pack $per.more -fill x -padx 16 -pady {8 12}
    bind $per.more <Button-1> {settingsShow screen}
    set dev [settingsBox $p.cols.r dev]
    label $dev.t -text "Сведения об устройстве" -bg #2d2d2d -fg #ffffff -font ui -anchor w
    label $dev.s -text "Данные этой машины" -bg #2d2d2d -fg #9a9a9a -font tiny -anchor w
    pack $dev.t -fill x -padx 16 -pady {12 0}
    pack $dev.s -fill x -padx 16 -pady {0 6}
    settingsFact $dev cpu "Процессор" [settingsCpuLine]
    settingsFact $dev mem "Память" [settingsMemLine]
    settingsFact $dev rel "Выпуск" [dict get $d pretty]
    settingsFact $dev os "Сборка ОС" [dict get $d rel]
    label $dev.more -text "Дополнительные сведения" -bg #2d2d2d -fg #e4c4a0 -font small -anchor w -cursor hand2
    pack $dev.more -fill x -padx 16 -pady {4 12}
    bind $dev.more <Button-1> {settingsShow about}
}
proc settingsLink {parent id title sub} {
    frame $parent.l$id -bg #2d2d2d -height 42 -cursor hand2
    pack $parent.l$id -fill x -padx 8
    pack propagate $parent.l$id 0
    label $parent.l$id.t -text $title -bg #2d2d2d -fg #ffffff -font small -anchor w -cursor hand2
    label $parent.l$id.s -text $sub -bg #2d2d2d -fg #9a9a9a -font tiny -anchor e -cursor hand2
    pack $parent.l$id.t -side left -padx 8
    pack $parent.l$id.s -side right -padx 8
    foreach w [list $parent.l$id $parent.l$id.t $parent.l$id.s] {
        bind $w <Button-1> [list settingsShow $id]
        bind $w <Enter> [list settingsTint $parent.l$id #383838]
        bind $w <Leave> [list settingsTint $parent.l$id #2d2d2d]
    }
}
proc settingsTint {f bg} {
    if {![winfo exists $f]} return
    $f configure -bg $bg
    foreach w [winfo children $f] { catch { $w configure -bg $bg } }
}
proc settingsFact {parent name cap val} {
    frame $parent.$name -bg #2d2d2d
    pack $parent.$name -fill x -padx 16 -pady 2
    label $parent.$name.c -text $cap -bg #2d2d2d -fg #9a9a9a -font tiny -anchor w
    label $parent.$name.v -text $val -bg #2d2d2d -fg #ffffff -font small -anchor w -justify left -wraplength 280
    pack $parent.$name.c -anchor w
    pack $parent.$name.v -anchor w
}
proc settingsFont {size} {
    set ::set_font $size
    settingsCommit 0
    if {$::setPage eq "home"} { settingsShow home }
    if {$::setPage eq "access"} { settingsShow access }
}
proc settingsApplyRes {res} {
    set ::set_res $res
    settingsCommit 1
    if {$::setPage eq "home"} { settingsShow home }
}
proc settingsAskHost {} {
    dialog "Имя устройства"
    entry .ask.in.e -bg $::CARD -fg $::WHITE -insertbackground $::ACCENT -font ui \
        -highlightthickness 1 -highlightbackground $::LINE -highlightcolor $::ACCENT
    pack .ask.in.e -fill x -padx 22 -ipady 6
    .ask.in.e insert 0 $::host
    .ask.in.e selection range 0 end
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 16
    button .ask.in.bt.ok -text "Сохранить" -command settingsHostGo -bg $::ACCENT -fg $::INK -font ui -padx 12 -pady 6
    button .ask.in.bt.no -text "Отмена" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
    pack .ask.in.bt.no .ask.in.bt.ok -side right -padx 10
    focus .ask.in.e
    bind .ask.in.e <Return> settingsHostGo
    bind .ask.in.e <Escape> { destroy .ask }
}
proc settingsPut {key value} {
    set conf /root/.deepos/settings
    file mkdir /root/.deepos
    set lines {}
    set found 0
    if {[file exists $conf]} {
        set fh [open $conf r]
        while {[gets $fh line] >= 0} {
            if {[string match $key=* $line]} {
                lappend lines "$key=$value"
                set found 1
            } else {
                lappend lines $line
            }
        }
        close $fh
    }
    if {!$found} { lappend lines "$key=$value" }
    set fh [open $conf w]
    puts $fh [join $lines \n]
    close $fh
}
proc settingsHostGo {} {
    set name ""
    if {[winfo exists .ask.in.e]} { set name [string trim [.ask.in.e get]] }
    catch { destroy .ask }
    if {![regexp {^[A-Za-z][A-Za-z0-9-]{0,31}$} $name]} {
        notify "Настройки" "Имя: латинские буквы, цифры и дефис"
        return
    }
    set ::host $name
    set ::set_host $name
    catch {
        set fh [open /etc/hostname w]
        puts $fh $name
        close $fh
    }
    catch { exec hostname $name }
    settingsPut HOSTNAME $name
    if {[winfo exists .wsettings.in.b.nav.who.m]} {
        .wsettings.in.b.nav.who.m configure -text "$::user@$::host"
    }
    settingsShow home
    notify "Настройки" "Имя устройства: $name"
}
proc settingsSystem {} {
    set p [settingsHead "Система"]
    settingsLink $p screen "Экран" $::set_res
    settingsLink $p sound "Звук" "$::set_vol%"
    settingsLink $p power "Питание" "Сон, перезагрузка, выключение"
    settingsLink $p about "О системе" [dict get [settingsFacts] pretty]
}
proc settingsApps {} {
    set p [settingsHead "Приложения"]
    label $p.note -text "Игры, браузеры и редакторы — в G-Store. Библиотеки и служебные пакеты — в программах для администратора." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w -wraplength 640 -justify left
    pack $p.note -fill x -padx 28
    label $p.go -text "Открыть G-Store" -bg #e4c4a0 -fg #1c1612 -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.go -anchor w -padx 28 -pady {10 4}
    bind $p.go <Button-1> {openApp gstore}
    label $p.adm -text "Программы для администратора" -bg #2d2d2d -fg #e4c4a0 -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.adm -anchor w -padx 28 -pady {4 10}
    bind $p.adm <Button-1> {openApp pkgs}
    set n 0
    foreach line [split [readFile /root/.deepos/world 20000] \n] {
        set line [string trim $line]
        if {$line eq ""} continue
        incr n
        label $p.p$n -text $line -bg #2d2d2d -fg #ffffff -font small -anchor w -padx 14 -pady 6
        pack $p.p$n -fill x -padx 28 -pady 2
        if {$n >= 30} break
    }
    if {$n == 0} {
        label $p.empty -text "Дополнительных программ пока нет" -bg #1f1f1f -fg #8a8a8a -font small -anchor w
        pack $p.empty -fill x -padx 28
    }
}
proc settingsTime {} {
    set p [settingsHead "Время и язык"]
    label $p.lang -text "Язык подписей в сохранённых настройках. Рабочий стол остаётся на русском." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w -wraplength 640 -justify left
    pack $p.lang -fill x -padx 28
    settingsChips $p ::set_lang {ru "Русский" en English}
    label $p.kb -text "Клавиатура. Alt+Shift переключает раскладки по кругу." -bg #1f1f1f -fg #9a9a9a -font small -anchor w
    pack $p.kb -fill x -padx 28 -pady {12 0}
    settingsChips $p ::set_kb {us,ru "EN + RU" us,ru,ua "EN + RU + UA" us,ru,de "EN + RU + DE" ua UA de DE fr FR ru RU us EN}
    label $p.hcap -text "Часы" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.hcap -fill x -padx 28 -pady {14 0}
    settingsChoice $p hour {24 "24 часа" 12 "12 часов"} ::set_h24 settingsHour
    label $p.dcap -text "Дата" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.dcap -fill x -padx 28 -pady {8 0}
    settingsChoice $p date {dmy "день.месяц.год" mdy "месяц/день/год"} ::set_date settingsDate
    label $p.zcap -text "Часовой пояс" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.zcap -fill x -padx 28 -pady {14 0}
    label $p.znote -text "На этом компьютере местное время — UTC+4, Самара." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w
    pack $p.znote -fill x -padx 28
    settingsChoice $p zone {
        Europe/Samara "Самара, UTC+4"
        Europe/Moscow "Москва, UTC+3"
        Asia/Yekaterinburg "Екатеринбург, UTC+5"
        Asia/Vladivostok "Владивосток, UTC+10"
        UTC UTC
    } ::set_tz settingsTz
}
proc themeTitle {} {
    switch -- $::set_theme {
        night { return "Ночь" }
        forest { return "Лес" }
        ink { return "Чернила" }
        contrast { return "Контраст" }
        default { return "Песок" }
    }
}
proc themeSpec {name} {
    switch -- $name {
        night { return [dict create bg #0e141c bar #15202b accent #8eb6e8 ink #101820 line #243044] }
        forest { return [dict create bg #101614 bar #1a2420 accent #9dcea6 ink #101814 line #24302a] }
        ink { return [dict create bg #0c0c0c bar #181818 accent #d8d8d8 ink #111111 line #2a2a2a] }
        contrast { return [dict create bg #000000 bar #000000 accent #ffe14a ink #000000 line #ffe14a] }
        default { return [dict create bg #111111 bar #1c1c1c accent #e4c4a0 ink #1c1612 line #2a2a2a] }
    }
}
proc themeApply {} {
    set name sand
    if {[info exists ::set_theme] && $::set_theme ne ""} { set name $::set_theme }
    set spec [themeSpec $name]
    set ::BG [dict get $spec bg]
    set ::BAR [dict get $spec bar]
    set ::ACCENT [dict get $spec accent]
    set ::INK [dict get $spec ink]
    if {[winfo exists .desk]} { .desk configure -bg $::BG }
    foreach w {.desk.bar .desk.bar.peek .desk.bar.clock .desk.bar.clock.t .desk.bar.clock.d .desk.bar.tray .desk.bar.mid .desk.bar.mid.pins} {
        if {[winfo exists $w]} { catch { $w configure -bg $::BAR } }
    }
    if {[winfo exists .desk.bar.line]} { .desk.bar.line configure -bg [dict get $spec line] }
    if {[winfo exists .desk.bar.tray]} {
        foreach c [winfo children .desk.bar.tray] { catch { $c configure -bg $::BAR } }
    }
    set clockfg #f3f3f3
    if {$name eq "contrast"} { set clockfg #ffff00 }
    catch { .desk.bar.clock.t configure -fg $clockfg }
    catch { .desk.bar.clock.d configure -fg $clockfg }
    if {[winfo exists .wx.in]} {
        .wx.in configure -bg $::BAR
        catch { .wx.in.t configure -bg $::BAR -fg $::ACCENT }
        catch { .wx.in.b configure -bg $::BAR }
    }
    unset -nocomplain ::pinKey
    paintPins
    paintWallpaper
}
proc settingsTheme {name} {
    set ::set_theme $name
    settingsPut THEME $name
    themeApply
    if {[info exists ::setPage] && ($::setPage eq "personal" || $::setPage eq "home")} {
        settingsShow $::setPage
    }
}
proc settingsWall {name} {
    set ::set_wall $name
    settingsPut WALL $name
    paintWallpaper
    if {[info exists ::setPage] && $::setPage eq "personal"} { settingsShow personal }
}
proc settingsWallUse {path} {
    catch { destroy .ask }
    if {![file exists $path]} {
        notify "Обои" "Файл не найден"
        return
    }
    catch { image delete ::wallimg }
    if {[catch {image create photo ::wallimg -file $path} err]} {
        notify "Обои" "Нужен PNG или GIF"
        return
    }
    set ::set_wall image
    set ::set_wallfile $path
    settingsPut WALL image
    settingsPut WALLFILE $path
    paintWallpaper
    if {[info exists ::setPage] && $::setPage eq "personal"} { settingsShow personal }
}
proc settingsWallFile {} {
    if {[winfo exists .ask]} { destroy .ask }
    toplevel .ask
    wm overrideredirect .ask 1
    wm geometry .ask 480x360+[expr {($::SW - 480) / 2}]+[expr {($::SH - 360) / 2}]
    .ask configure -bg $::ACCENT
    frame .ask.in -bg #1c1c1c
    pack .ask.in -fill both -expand 1 -padx 1 -pady 1
    label .ask.in.t -text "Рисунок рабочего стола" -bg #1c1c1c -fg #ffffff -font ui -anchor w
    pack .ask.in.t -fill x -padx 16 -pady {12 4}
    label .ask.in.n -text "PNG и GIF из домашней папки. JPEG рабочий стол не рисует." -bg #1c1c1c -fg #9a9a9a -font tiny -anchor w -wraplength 430 -justify left
    pack .ask.in.n -fill x -padx 16
    set files {}
    foreach dir {/root /root/Desktop /root/Pictures} {
        foreach f [glob -nocomplain -directory $dir *.png *.gif *.PNG *.GIF] {
            lappend files $f
        }
    }
    if {[llength $files] == 0} {
        label .ask.in.empty -text "Таких файлов нет" -bg #1c1c1c -fg #d0d0d0 -font small -anchor w
        pack .ask.in.empty -fill x -padx 16 -pady 12
    }
    set i 0
    foreach f $files {
        label .ask.in.f$i -text $f -bg #2d2d2d -fg #ffffff -font small -anchor w -padx 10 -pady 6 -cursor hand2
        pack .ask.in.f$i -fill x -padx 16 -pady 2
        bind .ask.in.f$i <Button-1> [list settingsWallUse $f]
        incr i
        if {$i >= 8} break
    }
    label .ask.in.no -text "Закрыть" -bg #3a3a3a -fg #ffffff -font small -padx 12 -pady 6 -cursor hand2
    pack .ask.in.no -anchor e -padx 16 -pady 12
    bind .ask.in.no <Button-1> { destroy .ask }
}
proc settingsClockPreset {name} {
    clockPickPreset $name
    if {[info exists ::setPage] && $::setPage eq "personal"} { settingsShow personal }
}
proc settingsClockSize {n} {
    set ::clkSize $n
    clockCommit
    if {[info exists ::setPage] && $::setPage eq "personal"} { settingsShow personal }
}
proc settingsChoice {parent prefix pairs var cmd} {
    frame $parent.$prefix -bg #1f1f1f
    pack $parent.$prefix -fill x -padx 24 -pady 4
    set cur ""
    if {[string match ::* $var]} { set cur [set $var] }
    foreach {value text} $pairs {
        set on 0
        if {$var ne "" && $cur eq $value} { set on 1 }
        if {$var eq "clk" && $::clkPreset eq $value} { set on 1 }
        if {$var eq "size" && $::clkSize == $value} { set on 1 }
        if {$var eq "con"} {
            if {$value eq "1" && $::set_theme eq "contrast"} { set on 1 }
            if {$value eq "0" && $::set_theme ne "contrast"} { set on 1 }
        }
        set bg #2d2d2d
        set fg #ffffff
        if {$on} { set bg #3a3328; set fg $::ACCENT }
        set name m[string map {. _ , _ x _ # {} / _} $value]
        label $parent.$prefix.$name -text $text -bg $bg -fg $fg -font small -padx 12 -pady 8 -cursor hand2
        pack $parent.$prefix.$name -side left -padx 4
        bind $parent.$prefix.$name <Button-1> [list {*}$cmd $value]
    }
}
proc settingsPersonal {} {
    set p [settingsHead "Персонализация"]
    label $p.note -text "Рисунок стола, цвет панели и часов. Светлой темы нет: меняется оттенок тёмного стола." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w -wraplength 700 -justify left
    pack $p.note -fill x -padx 28
    label $p.wcap -text "Рисунок рабочего стола" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.wcap -fill x -padx 28 -pady {12 0}
    settingsChoice $p wall {sand Песок night Ночь mist Туман forest Лес ink Чернила} ::set_wall settingsWall
    label $p.wfile -text "Свой PNG или GIF" -bg #2d2d2d -fg $::ACCENT -font small -padx 12 -pady 8 -cursor hand2
    pack $p.wfile -anchor w -padx 28 -pady {4 0}
    bind $p.wfile <Button-1> settingsWallFile
    if {$::set_wall eq "image" && $::set_wallfile ne ""} {
        label $p.wcur -text $::set_wallfile -bg #1f1f1f -fg #9a9a9a -font tiny -anchor w
        pack $p.wcur -fill x -padx 28
    }
    label $p.tcap -text "Цвет панели и акцента" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.tcap -fill x -padx 28 -pady {14 0}
    settingsChoice $p theme {sand Песок night Ночь forest Лес ink Чернила contrast Контраст} ::set_theme settingsTheme
    label $p.fcap -text "Шрифт интерфейса" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.fcap -fill x -padx 28 -pady {14 0}
    settingsChoice $p fam {dejavu "DejaVu Sans" unbounded Unbounded} ::set_fontfam settingsFontFam
    label $p.acap -text "Анимация панели" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.acap -fill x -padx 28 -pady {14 0}
    settingsChoice $p anim {off Выкл slow Медленно normal Обычно fast Быстро} ::set_anim settingsAnim
    label $p.scap -text "Звуки" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.scap -fill x -padx 28 -pady {14 0}
    settingsChoice $p snd {off Тихо soft Мягко click Щелчки} ::set_sound settingsSoundScheme
    label $p.termcap -text "Терминал" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.termcap -fill x -padx 28 -pady {14 0}
    settingsChoice $p termc {dark Тёмный light Светлый amber Янтарь contrast Контраст} ::set_termstyle settingsTermCol
    label $p.ccap -text "Часы" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.ccap -fill x -padx 28 -pady {14 0}
    settingsChoice $p preset {default Обычные aesthetic Эстетичные accessible Крупные} clk settingsClockPreset
    settingsChoice $p csize {110 Компакт 140 Обычный 170 Крупный 200 Огромный} size settingsClockSize
    label $p.more -text "Разрешение экрана" -bg #2d2d2d -fg $::ACCENT -font small -padx 12 -pady 8 -cursor hand2
    pack $p.more -anchor w -padx 28 -pady 12
    bind $p.more <Button-1> {settingsShow screen}
}
proc updNote {action detail} {
    catch {
        file mkdir /root/.deepos
        set fh [open /root/.deepos/updates.log a]
        puts $fh "[clock format [clock seconds] -format {%Y-%m-%d %H:%M}]\t$action\t$detail"
        close $fh
    }
    if {[info exists ::setPage] && $::setPage eq "updates" && [winfo exists .wsettings.in.b.page]} {
        settingsShow updates
    }
}
proc updatesCount {out} {
    set n 0
    foreach line [split $out \n] {
        if {[string match -nocase "*upgrading*" $line]} { incr n }
    }
    return $n
}
proc settingsUpdates {} {
    set p [settingsHead "Центр обновления"]
    set d [settingsFacts]
    settingsRow $p ver "Сборка" [dict get $d pretty]
    settingsRow $p rel "Ядро" [dict get $d rel]
    label $p.note -text "Кнопка ищет новые версии пакетов Alpine. Сам образ DeepOS обновляется новой сборкой на компьютере, где он запускается. Проверка также запускается сама и сообщает, если пакеты нашлись." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w -wraplength 700 -justify left
    pack $p.note -fill x -padx 28 -pady 8
    frame $p.act -bg #1f1f1f
    pack $p.act -anchor w -padx 28
    label $p.act.go -text "Проверить обновления" -bg $::ACCENT -fg $::INK -font ui -padx 14 -pady 8 -cursor hand2
    label $p.act.inst -text "Установить пакеты" -bg #2d2d2d -fg #ffffff -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.act.go $p.act.inst -side left -padx {0 8}
    bind $p.act.go <Button-1> updatesCheck
    bind $p.act.inst <Button-1> updatesGo
    set status "Автопроверка включена"
    if {[info exists ::updStatus] && $::updStatus ne ""} { set status $::updStatus }
    label $p.st -text $status -bg #1f1f1f -fg #d0d0d0 -font small -anchor w
    pack $p.st -fill x -padx 28 -pady {8 0}
    label $p.clog -text "Что в этой сборке" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.clog -fill x -padx 28 -pady {12 4}
    text $p.cl -bg #2d2d2d -fg #e8e8e8 -font small -height 7 -wrap word -highlightthickness 0
    pack $p.cl -fill x -padx 28
    set notes [readFile /usr/share/deepos/changelog 4000]
    if {$notes eq ""} { set notes "Список изменений для этой сборки не найден." }
    $p.cl insert end $notes
    $p.cl configure -state disabled
    label $p.hcap -text "История" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.hcap -fill x -padx 28 -pady {12 4}
    text $p.hi -bg #2d2d2d -fg #e8e8e8 -font small -height 6 -wrap word -highlightthickness 0
    pack $p.hi -fill x -padx 28 -pady {0 16}
    set hist [readFile /root/.deepos/updates.log 8000]
    if {[string trim $hist] eq ""} {
        set hist "Пока пусто. Записи появятся после проверки и установки пакетов."
    }
    $p.hi insert end $hist
    $p.hi configure -state disabled
}
proc settingsRow {parent name cap val} {
    frame $parent.$name -bg $::CARD
    pack $parent.$name -fill x -padx 28 -pady 4
    label $parent.$name.c -text $cap -bg $::CARD -fg $::ACCENT -font small -width 16 -anchor w
    label $parent.$name.v -text $val -bg $::CARD -fg $::WHITE -font small -anchor w -justify left
    pack $parent.$name.c -side left -padx 14 -pady 10
    pack $parent.$name.v -side left -fill x -expand 1 -padx {0 12}
}
proc settingsNet {} {
    set p [settingsHead "СЕТЬ"]
    set d [settingsFacts]
    settingsRow $p link "Состояние" [dict get $d netlabel]
    set iface [dict get $d iface]
    if {$iface eq ""} { set iface "—" }
    settingsRow $p if "Интерфейс" $iface
    set addr [dict get $d addr]
    if {$addr eq ""} { set addr "—" }
    settingsRow $p ip "Адрес" $addr
    set gw [dict get $d gw]
    if {$gw eq ""} { set gw "—" }
    settingsRow $p gw "Шлюз" $gw
    set dns [dict get $d dns]
    if {$dns eq ""} { set dns "—" }
    settingsRow $p dns "DNS" $dns
}
proc settingsSound {} {
    set p [settingsHead "ЗВУК"]
    label $p.cap -text "Громкость" -bg #141210 -fg $::WHITE -font ui -anchor w
    pack $p.cap -fill x -padx 28 -pady {8 4}
    scale $p.sc -from 0 -to 100 -orient horizontal -variable ::set_vol \
        -command settingsVolMove -length 420 -bg #141210 -fg $::WHITE \
        -troughcolor #3a342c -activebackground $::ACCENT -highlightthickness 0 \
        -sliderlength 16 -width 10 -showvalue 0
    pack $p.sc -anchor w -padx 28
    label $p.pct -text "$::set_vol%" -bg #141210 -fg $::GRAY -font small -anchor w
    pack $p.pct -fill x -padx 28 -pady {4 8}
    set cards [readFile /proc/asound/cards 800]
    set note "Звуковой карты нет. Процент сохранится, но вывести звук некуда."
    if {$cards ne "" && ![string match -nocase "*no sound*" $cards]} {
        set note "Громкость пишется в настройки и применяется к карте."
        settingsRow $p dev "Устройства" [string trim $cards]
    }
    label $p.note -text $note -bg #141210 -fg $::DIM -font small -anchor w -wraplength 520 -justify left
    pack $p.note -fill x -padx 28 -pady {8 0}
}
proc settingsVolMove {v} {
    set ::set_vol [expr {int($v)}]
    if {[winfo exists .wsettings.in.b.page.pct]} {
        .wsettings.in.b.page.pct configure -text "$::set_vol%"
    }
    if {[info exists ::volTick]} { after cancel $::volTick }
    set ::volTick [after 250 {settingsCommit 0}]
}
proc settingsChips {parent var pairs} {
    set row row_[string map {:: _ : _} $var]
    frame $parent.$row -bg #1f1f1f
    pack $parent.$row -fill x -padx 24 -pady 8
    foreach {value text} $pairs {
        set name m[string map {. _ , _} $value]
        settingsChip $parent.$row $name $text $var $value
    }
    paintChips $parent.$row
}
proc settingsChip {parent name text var value} {
    chip $parent $name $text $var $value
    bind $parent.$name <Button-1> [list settingsPick $parent $var $value]
}
proc settingsPick {parent var value} {
    pickChip $parent $var $value
    set refit 0
    if {$var eq "::set_res"} { set refit 1 }
    settingsCommit $refit
}
proc settingsScreen {} {
    set p [settingsHead "ЭКРАН"]
    label $p.cap -text "Разрешение" -bg #141210 -fg $::GRAY -font small -anchor w
    pack $p.cap -fill x -padx 28
    settingsChips $p ::set_res {
        1024x768 1024x768 1280x720 1280x720 1280x800 1280x800
        1366x768 1366x768 1600x900 1600x900 1920x1080 1920x1080
    }
}
proc settingsKb {} {
    set p [settingsHead "КЛАВИАТУРА"]
    label $p.cap -text "Раскладка. Alt+Shift переключает по кругу." -bg #141210 -fg $::GRAY -font small -anchor w
    pack $p.cap -fill x -padx 28
    settingsChips $p ::set_kb {us,ru "EN + RU" us,ru,ua "EN + RU + UA" us,ru,de "EN + RU + DE" ua UA de DE fr FR ru RU us EN}
}
proc settingsLang {} {
    set p [settingsHead "ЯЗЫК"]
    settingsChips $p ::set_lang {ru "Русский" en English}
}
proc tzApply {} {
    if {![info exists ::set_tz] || $::set_tz eq ""} { set ::set_tz Europe/Samara }
    if {![regexp {^[A-Za-z0-9_+/-]+$} $::set_tz]} { set ::set_tz Europe/Samara }
    set ::env(TZ) $::set_tz
    catch { exec ln -sf /usr/share/zoneinfo/$::set_tz /etc/localtime }
}
proc settingsTz {value} {
    set ::set_tz $value
    settingsPut TZ $value
    tzApply
    if {[info exists ::setPage] && $::setPage eq "time"} { settingsShow time }
}
proc settingsHour {value} {
    set ::set_h24 $value
    settingsPut CLOCK_H24 $value
}
proc settingsDate {value} {
    set ::set_date $value
    settingsPut DATE_FMT $value
}
proc settingsFontFam {value} {
    set ::set_fontfam $value
    settingsPut FONT_FAMILY $value
    fontApply
}
proc fontApply {} {
    set fam "DejaVu Sans"
    if {[info exists ::set_fontfam] && $::set_fontfam eq "unbounded"} { set fam "Unbounded" }
    foreach fn {ui title small tiny task taskb uib} {
        if {[lsearch -exact [font names] $fn] < 0} continue
        catch { font configure $fn -family $fam }
    }
}
proc settingsAnim {value} {
    set ::set_anim $value
    settingsPut ANIM $value
}
proc settingsSoundScheme {value} {
    set ::set_sound $value
    settingsPut SOUND $value
    if {$value ne "off"} { soundPlay click }
}
proc settingsTermCol {value} {
    switch -- $value {
        light { set ::set_termbg #f4efe8; set ::set_termfg #1c1612 }
        amber { set ::set_termbg #1a1208; set ::set_termfg #e4c4a0 }
        contrast { set ::set_termbg #000000; set ::set_termfg #ffff00 }
        default { set ::set_termbg #0c0c0c; set ::set_termfg #cccccc; set value dark }
    }
    set ::set_termstyle $value
    settingsPut TERM_STYLE $value
    settingsPut TERM_BG [string trimleft $::set_termbg #]
    settingsPut TERM_FG [string trimleft $::set_termfg #]
    termApplyColors
}
proc soundPlay {kind} {
    if {![info exists ::set_sound] || $::set_sound eq "" || $::set_sound eq "off"} return
    set file /usr/share/deepos/sounds/click.wav
    if {$kind eq "welcome"} { set file /usr/share/deepos/sounds/welcome.wav }
    if {$::set_sound eq "soft" && $kind ne "welcome"} { set file /usr/share/deepos/sounds/soft.wav }
    if {![file exists $file]} return
    catch { exec aplay -q $file & }
}
proc speak {text} {
    if {![info exists ::set_speak] || $::set_speak ne "1"} return
    if {$text eq ""} return
    speakShow $text
    catch { exec espeak-ng -v ru -s 150 $text & }
}
proc speakShow {text} {
    if {![winfo exists .speak]} {
        toplevel .speak
        wm overrideredirect .speak 1
        .speak configure -bg #000000
        label .speak.t -text "" -bg #000000 -fg #ffff00 -font ui -anchor w
        pack .speak.t -fill x -padx 16 -pady 8
    }
    .speak.t configure -text $text
    wm geometry .speak 720x40+[expr {($::SW - 720) / 2}]+12
    raise .speak
}
proc speakSet {value} {
    set ::set_speak $value
    settingsPut SPEAK $value
    if {$value eq "1"} {
        speakShow "Озвучка включена"
        catch { exec espeak-ng -v ru -s 150 "Озвучка включена" & }
    } else {
        catch { destroy .speak }
    }
    if {[info exists ::setPage] && $::setPage eq "access"} { settingsShow access }
}
proc cursorOn {size x y} {
    if {$x < 1 || $y < 1} { return 0 }
    set head [expr {$size * 0.42}]
    set thick [expr {$size * 0.16}]
    if {$thick < 3} { set thick 3 }
    if {$y < $thick && $x < $head} { return 1 }
    if {$x < $thick && $y < $head} { return 1 }
    set lim [expr {$size * 0.78}]
    set band [expr {$size * 0.09}]
    if {$band < 2} { set band 2 }
    if {$x < $lim && $y < $lim && abs($x - $y) <= $band} { return 1 }
    return 0
}
proc cursorMaskOn {size x y} {
    for {set dy -1} {$dy <= 1} {incr dy} {
        for {set dx -1} {$dx <= 1} {incr dx} {
            set xx [expr {$x + $dx}]
            set yy [expr {$y + $dy}]
            if {$xx < 0 || $yy < 0 || $xx >= $size || $yy >= $size} continue
            if {[cursorOn $size $xx $yy]} { return 1 }
        }
    }
    return 0
}
proc cursorWrite {size path fill} {
    set rowb [expr {($size + 7) / 8}]
    set fh [open $path w]
    puts $fh "#define cursor_width $size"
    puts $fh "#define cursor_height $size"
    puts $fh "#define cursor_x_hot 1"
    puts $fh "#define cursor_y_hot 1"
    puts $fh "static unsigned char cursor_bits\[\] = \{"
    set parts {}
    for {set y 0} {$y < $size} {incr y} {
        for {set b 0} {$b < $rowb} {incr b} {
            set val 0
            for {set bit 0} {$bit < 8} {incr bit} {
                set x [expr {$b * 8 + $bit}]
                if {$x >= $size} continue
                set on 0
                if {$fill} {
                    set on [cursorOn $size $x $y]
                } else {
                    set on [cursorMaskOn $size $x $y]
                }
                if {$on} { set val [expr {$val | (1 << $bit)}] }
            }
            lappend parts [format "0x%02x" $val]
        }
    }
    puts $fh "  [join $parts {, }]"
    puts $fh "\};"
    close $fh
}
proc cursorApply {} {
    set size 16
    if {[info exists ::set_csize]} { set size $::set_csize }
    if {$size != 16 && $size != 32 && $size != 48} { set size 16 }
    set color #ffffff
    if {[info exists ::set_ccolor] && $::set_ccolor ne ""} { set color $::set_ccolor }
    set cur /tmp/deepos-cursor.xbm
    set mask /tmp/deepos-cursor-mask.xbm
    if {[catch {
        cursorWrite $size $cur 1
        cursorWrite $size $mask 0
        exec xsetroot -fg $color -bg #000000 -cursor $cur $mask
    } err]} {
        catch { exec xsetroot -cursor_name left_ptr }
    }
}
proc settingsCursorSize {value} {
    set ::set_csize $value
    settingsPut CURSOR_SIZE $value
    cursorApply
}
proc settingsCursorColor {value} {
    set ::set_ccolor $value
    settingsPut CURSOR_COLOR [string trimleft $value #]
    cursorApply
}
proc magTick {} {
    if {![winfo exists .mag.c]} return
    set x [winfo pointerx .]
    set y [winfo pointery .]
    set x0 [expr {$x - 80}]
    set y0 [expr {$y - 50}]
    if {$x0 < 0} { set x0 0 }
    if {$y0 < 0} { set y0 0 }
    set png /tmp/deepos-mag.png
    if {[catch {exec scrot -o -a ${x0},${y0},160,100 $png} err]} {
        .mag.c delete all
        .mag.c create text 12 16 -anchor nw -fill #ffffff -font small -text "Лупа не смогла снять область экрана"
        after 900 magTick
        return
    }
    catch { image delete magraw }
    if {[catch {image create photo magraw -file $png}]} {
        after 900 magTick
        return
    }
    catch { image delete magview }
    image create photo magview
    magview copy magraw -zoom 2 2
    image delete magraw
    .mag.c delete all
    .mag.c create image 0 0 -anchor nw -image magview
    after 450 magTick
}
proc magToggle {} {
    if {[winfo exists .mag]} {
        destroy .mag
        catch { image delete magview }
        if {[info exists ::setPage] && $::setPage eq "access"} { settingsShow access }
        return
    }
    toplevel .mag
    wm overrideredirect .mag 1
    .mag configure -bg #ffe14a
    canvas .mag.c -width 320 -height 200 -bg #000000 -highlightthickness 0
    pack .mag.c -padx 2 -pady 2
    wm geometry .mag 324x204+20+[expr {$::SH - $::BARH - 230}]
    raise .mag
    magTick
    if {[info exists ::setPage] && $::setPage eq "access"} { settingsShow access }
}
proc oskSend {key} {
    set wid ""
    if {[info exists ::oskPrev] && $::oskPrev ne ""} { set wid $::oskPrev }
    if {$key eq "BackSpace" || $key eq "Return" || $key eq "space"} {
        if {$wid ne ""} {
            catch { exec xdotool key --window $wid $key }
        } else {
            catch { exec xdotool key $key }
        }
    } else {
        if {$wid ne ""} {
            catch { exec xdotool type --window $wid -- $key }
        } else {
            catch { exec xdotool type -- $key }
        }
    }
    speak $key
}
proc oskKey {parent row col text key} {
    set w $parent.k${row}_$col
    label $w -text $text -bg #2d2d2d -fg #ffffff -font ui -width 4 -pady 8 -cursor hand2
    grid $w -row $row -column $col -padx 2 -pady 2 -sticky nsew
    bind $w <Button-1> [list oskSend $key]
    bind $w <Enter> [list $w configure -bg #3a3328]
    bind $w <Leave> [list $w configure -bg #2d2d2d]
}
proc oskRedraw {} {
    set g .osk.in.keys
    if {![winfo exists $g]} return
    foreach c [winfo children $g] { destroy $c }
    if {![info exists ::oskLat]} { set ::oskLat 0 }
    if {$::oskLat} {
        set rows {
            {1 2 3 4 5 6 7 8 9 0}
            {q w e r t y u i o p}
            {a s d f g h j k l}
            {z x c v b n m}
        }
    } else {
        set rows {
            {1 2 3 4 5 6 7 8 9 0}
            {й ц у к е н г ш щ з}
            {ф ы в а п р о л д}
            {я ч с м и т ь б ю}
        }
    }
    set r 0
    foreach row $rows {
        set c 0
        foreach ch $row {
            oskKey $g $r $c $ch $ch
            incr c
        }
        incr r
    }
    oskKey $g 4 0 "пробел" space
    oskKey $g 4 1 "ввод" Return
    oskKey $g 4 2 "стереть" BackSpace
}
proc oskToggleLang {} {
    if {![info exists ::oskLat]} { set ::oskLat 0 }
    set ::oskLat [expr {!$::oskLat}]
    oskRedraw
}
proc oskToggle {} {
    if {[winfo exists .osk]} {
        destroy .osk
        if {[info exists ::setPage] && $::setPage eq "access"} { settingsShow access }
        return
    }
    catch { set ::oskPrev [exec xdotool getactivewindow] }
    toplevel .osk
    wm overrideredirect .osk 1
    wm title .osk "DeepOS Keys"
    .osk configure -bg #111111
    frame .osk.in -bg #1c1c1c
    pack .osk.in -fill both -expand 1 -padx 1 -pady 1
    frame .osk.in.bar -bg #1c1c1c
    pack .osk.in.bar -fill x
    label .osk.in.bar.t -text "Экранная клавиатура" -bg #1c1c1c -fg #ffffff -font small
    label .osk.in.bar.lat -text "EN / RU" -bg #2d2d2d -fg #e4c4a0 -font small -padx 10 -pady 4 -cursor hand2
    label .osk.in.bar.x -text "Закрыть" -bg #2d2d2d -fg #ffffff -font small -padx 10 -pady 4 -cursor hand2
    pack .osk.in.bar.x .osk.in.bar.lat -side right -padx 6 -pady 6
    pack .osk.in.bar.t -side left -padx 12
    bind .osk.in.bar.lat <Button-1> oskToggleLang
    bind .osk.in.bar.x <Button-1> oskToggle
    frame .osk.in.keys -bg #1c1c1c
    pack .osk.in.keys -padx 8 -pady {0 8}
    oskRedraw
    set width 760
    set height 280
    wm geometry .osk ${width}x${height}+[expr {($::SW - $width) / 2}]+[expr {$::SH - $::BARH - $height - 12}]
    raise .osk
    if {[info exists ::setPage] && $::setPage eq "access"} { settingsShow access }
}
proc settingsAccess {} {
    set p [settingsHead "Специальные возможности"]
    label $p.cap -text "Размер шрифта терминала" -bg #1f1f1f -fg #9a9a9a -font small -anchor w
    pack $p.cap -fill x -padx 28
    settingsChips $p ::set_font {12 "По умолчанию" 14 "Средний" 16 "Крупный" 20 "Огромный"}
    label $p.ct -text "Высокий контраст" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.ct -fill x -padx 28 -pady {12 0}
    set con 0
    if {$::set_theme eq "contrast"} { set con 1 }
    settingsChoice $p contrast [list 0 Обычная 1 "Чёрный и жёлтый"] con accessContrast
    label $p.mt -text "Лупа" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.mt -fill x -padx 28 -pady {12 0}
    set mag "Открыть лупу"
    if {[winfo exists .mag]} { set mag "Закрыть лупу" }
    label $p.mag -text $mag -bg #2d2d2d -fg $::ACCENT -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.mag -anchor w -padx 28
    bind $p.mag <Button-1> magToggle
    label $p.cs -text "Курсор" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.cs -fill x -padx 28 -pady {12 0}
    settingsChoice $p csz {16 Обычный 32 Крупный 48 Огромный} ::set_csize settingsCursorSize
    settingsChoice $p ccol [list #ffffff Белый #ffe14a Жёлтый #e4c4a0 Песок #7ee0ff Голубой] ::set_ccolor settingsCursorColor
    label $p.ot -text "Экранная клавиатура" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.ot -fill x -padx 28 -pady {12 0}
    set osk "Открыть клавиатуру"
    if {[winfo exists .osk]} { set osk "Закрыть клавиатуру" }
    label $p.osk -text $osk -bg #2d2d2d -fg $::ACCENT -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.osk -anchor w -padx 28
    bind $p.osk <Button-1> oskToggle
    label $p.st -text "Озвучка" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.st -fill x -padx 28 -pady {12 0}
    label $p.sn -text "Читает название окна и текст уведомления. Голос — espeak, если он установлен." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w -wraplength 700 -justify left
    pack $p.sn -fill x -padx 28
    settingsChoice $p spk {0 Выкл 1 Вкл} ::set_speak speakSet
}
proc settingsAbout {} {
    set p [settingsHead "О СИСТЕМЕ"]
    set d [settingsFacts]
    set info [sysinfo]
    settingsRow $p ver "Система" [dict get $d pretty]
    settingsRow $p rel "Ядро" [dict get $d rel]
    settingsRow $p mem "Память" [lindex $info 1]
    settingsRow $p base "Основа" "Alpine Linux"
}
proc settingsAccount {} {
    set p [settingsHead "УЧЁТНАЯ ЗАПИСЬ"]
    if {![info exists ::accountId] || $::accountId eq ""} {
        label $p.none -text "Сначала войдите в учётку." -bg #1f1f1f -fg #9a9a9a -font ui -anchor w
        pack $p.none -fill x -padx 28
        return
    }
    array set m [accountMeta $::accountId]
    label $p.n1 -text "Имя" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.n1 -fill x -padx 28
    entry $p.name -bg #2a2a2a -fg #ffffff -insertbackground #e4c4a0 -font ui -relief flat
    pack $p.name -anchor w -padx 28 -pady 6 -ipady 4
    $p.name insert 0 $m(name)
    label $p.a1 -text "Аватар" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.a1 -fill x -padx 28 -pady {8 0}
    frame $p.avs -bg #1f1f1f
    pack $p.avs -anchor w -padx 28 -pady 6
    set ::accountEditAvatar $m(avatar)
    for {set a 0} {$a < 6} {incr a} {
        canvas $p.avs.c$a -width 48 -height 48 -bg #1f1f1f -highlightthickness 0 -cursor hand2
        pack $p.avs.c$a -side left -padx 4
        bind $p.avs.c$a <Button-1> [list accountEditAvatar $a]
    }
    accountEditAvatar $::accountEditAvatar
    label $p.save -text "Сохранить имя и аватар" -bg #e4c4a0 -fg #1c1612 -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.save -anchor w -padx 28 -pady {4 12}
    bind $p.save <Button-1> accountSaveProfile
    label $p.p1 -text "Текущий пароль или PIN" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.p1 -fill x -padx 28
    entry $p.old -show * -bg #2a2a2a -fg #ffffff -insertbackground #e4c4a0 -font ui -relief flat
    pack $p.old -anchor w -padx 28 -pady 4 -ipady 4
    label $p.p2 -text "Новый пароль или PIN" -bg #1f1f1f -fg #ffffff -font ui -anchor w
    pack $p.p2 -fill x -padx 28 -pady {8 0}
    entry $p.new1 -show * -bg #2a2a2a -fg #ffffff -insertbackground #e4c4a0 -font ui -relief flat
    pack $p.new1 -anchor w -padx 28 -pady 4 -ipady 4
    entry $p.new2 -show * -bg #2a2a2a -fg #ffffff -insertbackground #e4c4a0 -font ui -relief flat
    pack $p.new2 -anchor w -padx 28 -pady 4 -ipady 4
    label $p.err -text "" -bg #1f1f1f -fg #e81123 -font small -anchor w
    pack $p.err -fill x -padx 28
    label $p.pw -text "Сменить пароль" -bg #2d2d2d -fg #e4c4a0 -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.pw -anchor w -padx 28 -pady 8
    bind $p.pw <Button-1> accountSaveSecret
    frame $p.row -bg #1f1f1f
    pack $p.row -anchor w -padx 28 -pady 8
    label $p.row.lock -text "Заблокировать" -bg #2d2d2d -fg #f6f1ea -font ui -padx 14 -pady 8 -cursor hand2
    label $p.row.out -text "Выйти из учётки" -bg #2d2d2d -fg #f6f1ea -font ui -padx 14 -pady 8 -cursor hand2
    pack $p.row.lock $p.row.out -side left -padx 4
    bind $p.row.lock <Button-1> lockSession
    bind $p.row.out <Button-1> doLogout
}
proc settingsPower {} {
    set p [settingsHead "ПИТАНИЕ"]
    frame $p.row -bg #141210
    pack $p.row -anchor w -padx 28 -pady 12
    foreach {name text cmd} {sleep "Сон" doSleep reboot "Перезагрузка" doReboot off "Выключение" doShutdown} {
        button $p.row.$name -text $text -command $cmd -bg $::CARD -fg $::WHITE -font ui \
            -activebackground $::ACCENT -activeforeground $::INK -padx 16 -pady 10 -cursor hand2
        pack $p.row.$name -side left -padx 6
    }
    label $p.note -text "Сон пишет mem в /sys/power/state. Если режим недоступен, появится сообщение." \
        -bg #141210 -fg $::DIM -font small -anchor w -wraplength 520 -justify left
    pack $p.note -fill x -padx 28
}
proc settingsCommit {{refit 0}} {
    set rc [catch {exec /usr/bin/deepos-settings-apply save $::set_res $::set_lang $::set_kb $::set_font $::set_vol} err]
    set status OK
    if {[file exists /tmp/deepos-settings.status]} {
        set status [string trim [readFile /tmp/deepos-settings.status 80]]
    }
    if {![winfo exists .wsettings.in.b.main.st]} return
    if {$rc != 0 || [string match ERR* $status]} {
        .wsettings.in.b.main.st configure -text "Не удалось применить." -fg $::DANGER
        return
    }
    catch { font configure mono -size $::set_font }
    catch { font configure termfont -size $::set_font }
    catch { exec amixer -q sset Master $::set_vol% unmute }
    catch { exec amixer -q sset PCM $::set_vol% unmute }
    .wsettings.in.b.main.st configure -text "Сохранено" -fg $::ACCENT
    if {$refit} { after 300 fitDesktop }
}
proc applySettings {} { settingsCommit 1 }

proc accessContrast {value} {
    if {$value eq "1" || $value == 1} {
        if {$::set_theme ne "contrast"} { set ::set_theme_prev $::set_theme }
        settingsTheme contrast
    } else {
        set back sand
        if {[info exists ::set_theme_prev] && $::set_theme_prev ne "" && $::set_theme_prev ne "contrast"} {
            set back $::set_theme_prev
        }
        settingsTheme $back
    }
    if {[info exists ::setPage] && $::setPage eq "access"} { settingsShow access }
}
proc notify {title body} {
    if {![permAllows notify]} {
        journalAdd info Разрешения "Уведомление скрыто: $title"
        return
    }
    speak "$title. $body"
    if {![info exists ::toastN]} { set ::toastN 0 }
    if {![info exists ::toastTop]} { set ::toastTop {} }
    set n [incr ::toastN]
    set w .toast$n
    toplevel $w
    wm overrideredirect $w 1
    $w configure -bg #3a3a3a
    frame $w.in -bg #1c1c1c
    pack $w.in -fill both -expand 1 -padx 1 -pady 1
    label $w.in.t -text $title -bg #1c1c1c -fg #f6f1ea -font ui -anchor w
    label $w.in.b -text $body -bg #1c1c1c -fg #a3988c -font small -anchor w -wraplength 280 -justify left
    pack $w.in.t -fill x -padx 14 -pady {10 2}
    pack $w.in.b -fill x -padx 14 -pady {0 12}
    lappend ::toastTop $w
    notifyPlace
    after 4200 [list notifyClose $w]
    raise $w
}
proc notifyClose {w} {
    catch { destroy $w }
    if {![info exists ::toastTop]} return
    set left {}
    foreach item $::toastTop {
        if {$item ne $w && [winfo exists $item]} { lappend left $item }
    }
    set ::toastTop $left
    notifyPlace
}
proc notifyPlace {} {
    if {![info exists ::toastTop]} return
    set y [expr {$::SH - $::BARH - 16}]
    foreach w $::toastTop {
        if {![winfo exists $w]} continue
        set y [expr {$y - 78}]
        wm geometry $w 320x72+[expr {$::SW - 336}]+$y
    }
}
proc jobStart {cmd done {tick ""}} {
    set pipe [open $cmd r]
    fconfigure $pipe -blocking 0
    set ::jobAcc($pipe) ""
    set ::jobDone($pipe) $done
    set ::jobTick($pipe) $tick
    fileevent $pipe readable [list jobDrain $pipe]
}
proc jobDrain {pipe} {
    if {![info exists ::jobAcc($pipe)]} return
    while {1} {
        set line ""
        set n -1
        catch { set n [gets $pipe line] }
        if {$n < 0} break
        append ::jobAcc($pipe) $line \n
        if {[info exists ::jobTick($pipe)] && $::jobTick($pipe) ne ""} {
            uplevel #0 [list {*}$::jobTick($pipe) $line]
        }
    }
    set closed 0
    catch { set closed [eof $pipe] }
    if {!$closed} return
    set rest ""
    catch { set rest [read $pipe] }
    append ::jobAcc($pipe) $rest
    set out $::jobAcc($pipe)
    set done $::jobDone($pipe)
    catch { fileevent $pipe readable {} }
    if {[catch { close $pipe } cerr]} { append out \n $cerr }
    unset -nocomplain ::jobAcc($pipe) ::jobDone($pipe) ::jobTick($pipe)
    uplevel #0 [list {*}$done $out]
}
proc gstoreCatalog {} {
    return {
        {games SuperTux supertux bin {Платформер: прыжки, лёд и уровни.} platform 4.8}
        {games SuperTuxKart supertuxkart bin {Гонки на картах с бонусами.} race 4.7}
        {games Xonotic xonotic bin {Быстрая арена и стрельба.} arena 4.6}
        {games Wesnoth wesnoth bin {Пошаговые битвы и отряды.} strat 4.8}
        {games Widelands widelands bin {Посёлок, дороги и захват земель.} strat 4.5}
        {games FreeCiv freeciv bin {Города, наука и соседи.} strat 4.4}
        {games OpenTTD openttd bin {Поезда, дороги и растущие города.} strat 4.7}
        {games Minetest luanti bin {Мир из кубиков. В каталоге это Luanti.} world 4.6}
        {games Pingus pingus bin {Загадки: доведи пингвинов до выхода.} puzzle 4.4}
        {games LBreakout2 lbreakout2 bin {Аркада: отбивай кирпичи.} arcade 4.2}
        {games ScummVM scummvm bin {Старые квесты в одном окне.} emu 4.5}
        {games {DOSBox Staging} dosbox-staging bin {Старые игры в отдельном окне.} emu 4.5}
        {games RetroArch retroarch bin {Зал для своих игровых образов.} emu 4.4}
        {games Mednafen mednafen bin {Ещё один зал для образов игр.} emu 4.2}
        {games Mupen64Plus mupen64plus bin {Образы консольных игр.} emu 4.3}
        {talk DeepChat {} chat {Сообщения этого компьютера. Никуда не отправляются.} chat 4.9}
        {talk Telegram telegram-desktop bin {Чаты, каналы и звонки.} chat 4.7}
        {talk Dino dino bin {Переписка в своей учётной записи.} chat 4.4}
        {talk Nheko nheko bin {Комнаты и общие чаты.} chat 4.5}
        {talk Pidgin pidgin bin {Несколько сетей в одном окне.} chat 4.2}
        {net {Sun Browser} {} browse {Браузер этого стола.} web 4.6}
        {net Firefox firefox firefox {Вкладки, закладки и расширения.} web 4.8}
        {net Chromium chromium chrome {Второй браузер, уже на столе.} web 4.7}
        {net Thunderbird thunderbird bin {Почта в своём ящике.} mail 4.5}
        {net FileZilla filezilla bin {Передача файлов на сервер.} ftp 4.3}
        {net Transmission transmission-gtk bin {Загрузки больших файлов.} ftp 4.4}
        {art GIMP gimp bin {Рисунки, слои и правка фото.} draw 4.8}
        {art Krita krita bin {Кисти и холст для рисунка.} draw 4.7}
        {art Inkscape inkscape bin {Знаки, кривые и вектор.} draw 4.6}
        {art Blender blender bin {Трёхмерные сцены и герои.} model 4.8}
        {art Darktable darktable bin {Проявка и цвет фотографий.} photo 4.5}
        {art Audacity audacity bin {Запись и правка звука.} audio 4.6}
        {art {OBS Studio} obs-studio bin {Запись экрана и эфир.} video 4.5}
        {art VLC vlc bin {Кино, музыка и сеть.} play 4.7}
        {art mpv mpv bin {Проигрыватель без лишнего.} play 4.4}
        {art Celluloid celluloid bin {Кино в простом окне.} play 4.3}
        {art Strawberry strawberry bin {Своя полка с музыкой.} music 4.5}
        {art Rhythmbox rhythmbox bin {Музыка и радио.} music 4.3}
        {art Kodi kodi bin {Медиацентр на весь экран.} play 4.4}
        {art Shotwell shotwell bin {Альбом фотографий.} photo 4.2}
        {art LibreOffice libreoffice-writer bin {Тексты, письма и страницы.} doc 4.6}
        {art {LibreOffice Таблицы} libreoffice-calc bin {Числа, формулы и листы.} sheet 4.5}
        {art {LibreOffice Слайды} libreoffice-impress bin {Показ слайдов.} slides 4.4}
        {tool Geany geany bin {Редактор кода с подсветкой.} code 4.5}
        {tool Архиватор xarchiver bin {Архивы zip и 7z.} tool 4.3}
        {tool Калькулятор galculator bin {Обычные и инженерные расчёты.} tool 4.4}
        {tool Блокнот mousepad bin {Простой текст без оформления.} doc 4.3}
        {tool {Просмотр PDF} evince bin {Страницы PDF.} doc 4.4}
        {tool KeePassXC keepassxc bin {Пароли в своей базе.} lock 4.7}
        {tool GParted gparted bin {Разделы диска.} disk 4.3}
        {tool gThumb gthumb bin {Просмотр снимков.} photo 4.2}
        {tool AbiWord abiword bin {Короткий текст и письмо.} doc 4.1}
        {tool Gnumeric gnumeric bin {Лёгкие таблицы.} sheet 4.2}
        {tool {Снимок экрана} {} shot {Снимок этого стола.} shot 4.6}
    }
}
proc gstoreHave {out} {
    array unset ::gstoreOn
    array set ::gstoreOn {}
    foreach name [pkgNames $out] { set ::gstoreOn($name) 1 }
    set ::gstoreReady 1
    gstoreRender
}
proc gstoreInstalled {pkg} {
    if {$pkg eq ""} { return 0 }
    if {![info exists ::gstoreReady] || !$::gstoreReady} { return 0 }
    if {[info exists ::gstoreOn($pkg)]} { return 1 }
    return 0
}
proc openGuest {title bin} {
    if {![file executable $bin]} {
        notify "Программа" "Файл не найден"
        return
    }
    set id app[clock milliseconds]
    set ::title($id) $title
    set ::pintitle($id) $title
    set ::pinicon($id) gstore
    set base [file tail $bin]
    set ::hostPids($id) [list $base]
    set ::hostBin($id) $base
    set ::hostSeen($id) [hostSeenNow [list $base]]
    if {[guestDenied $title $bin]} { return }
    set q [string map {' '\\''} $bin]
    set homeExtra ""
    if {![permAllows files]} {
        file mkdir /tmp/deepos-sandbox
        set homeExtra "HOME=/tmp/deepos-sandbox "
        journalAdd info Разрешения "$title без доступа к файлам учётки"
    }
    openHostApp $id $title "${homeExtra}GDK_BACKEND=x11 exec '$q'" [list $base]
}
proc gstoreAct {title pkg app} {
    if {$app eq "none"} {
        notify "G-Store" "Эту программу нельзя поставить из каталога"
        return
    }
    if {$app eq "chat"} { openChat; return }
    if {$app eq "browse"} { openBrowse; return }
    if {$app eq "firefox"} { openFirefox; return }
    if {$app eq "chrome"} { openChrome; return }
    if {$app eq "shot"} { takeShot; return }
    if {[gstoreInstalled $pkg]} {
        set bin [pkgPickBin $pkg]
        if {$bin eq ""} {
            notify "G-Store" "Не найден файл запуска $title"
            return
        }
        if {[pkgGui $bin]} {
            openGuest $title $bin
        } else {
            termExec $bin
        }
        return
    }
    if {![permAllows net]} {
        notify "G-Store" "Установка запрещена: нет доступа к сети"
        journalAdd warn Разрешения "Установка $title запрещена"
        return
    }
    notify "G-Store" "Устанавливаю $title"
    journalAdd info Пакеты "Установка: $title"
    jobStart [list | /bin/sh -c "/usr/bin/deepos-pkg add [pkgQuote $pkg] 2>&1"] [list gstoreAddDone $pkg $title]
}
proc gstoreErr {out} {
    set pick ""
    foreach line [split $out \n] {
        set line [string trim $line]
        if {$line eq ""} continue
        if {[string match -nocase "ERROR:*" $line] || [string match -nocase "*unable to*" $line] || [string match -nocase "*no such package*" $line] || [string match -nocase "*unsatisfiable*" $line] || [string match -nocase "*failed*" $line]} {
            set pick $line
        }
    }
    if {[string length $pick] > 120} { set pick "[string range $pick 0 118]..." }
    return $pick
}
proc gstoreAddDone {pkg title out} {
    set why [gstoreErr $out]
    if {$why ne ""} {
        journalAdd error Пакеты "Не установлено: $title"
        notify "G-Store" $why
        return
    }
    journalAdd info Пакеты "Установлено: $title"
    set ::gstoreOn($pkg) 1
    set ::gstoreReady 1
    updNote "установка" $pkg
    set link [pkgWriteShortcut $pkg]
    paintDeskIcons
    if {$link eq ""} {
        notify "G-Store" "Установлено: $title"
    } else {
        notify "G-Store" "Установлено: $title. Ярлык на столе."
    }
    gstoreRender
}
proc gstoreFonts {} {
    catch {font create storehero -family "DejaVu Sans" -size 26 -weight bold}
    catch {font create storesub -family "DejaVu Sans" -size 12}
}
proc gstoreRound {c x1 y1 x2 y2 r args} {
    if {$x2 < $x1} { set t $x1; set x1 $x2; set x2 $t }
    if {$y2 < $y1} { set t $y1; set y1 $y2; set y2 $t }
    set rw [expr {($x2 - $x1) / 2.0}]
    set rh [expr {($y2 - $y1) / 2.0}]
    set r [expr {min(double($r), $rw, $rh)}]
    array set opt [list -fill "" -outline "" -tags "" -width 1]
    array set opt $args
    set fill $opt(-fill)
    set tags $opt(-tags)
    if {$fill eq ""} { return }
    set d [expr {$r * 2.0}]
    $c create arc $x1 $y1 [expr {$x1 + $d}] [expr {$y1 + $d}] -start 90 -extent 90 -style pieslice -fill $fill -outline {} -tags $tags
    $c create arc [expr {$x2 - $d}] $y1 $x2 [expr {$y1 + $d}] -start 0 -extent 90 -style pieslice -fill $fill -outline {} -tags $tags
    $c create arc $x1 [expr {$y2 - $d}] [expr {$x1 + $d}] $y2 -start 180 -extent 90 -style pieslice -fill $fill -outline {} -tags $tags
    $c create arc [expr {$x2 - $d}] [expr {$y2 - $d}] $x2 $y2 -start 270 -extent 90 -style pieslice -fill $fill -outline {} -tags $tags
    $c create rectangle [expr {$x1 + $r}] $y1 [expr {$x2 - $r}] $y2 -fill $fill -outline {} -tags $tags
    $c create rectangle $x1 [expr {$y1 + $r}] $x2 [expr {$y2 - $r}] -fill $fill -outline {} -tags $tags
}
proc gstoreStar {c cx cy r fill} {
    set pts {}
    for {set i 0} {$i < 10} {incr i} {
        set ang [expr {($i * 36 - 90) * 0.01745329252}]
        if {($i % 2) == 0} { set rad $r } else { set rad [expr {$r * 0.42}] }
        lappend pts [expr {$cx + cos($ang) * $rad}] [expr {$cy + sin($ang) * $rad}]
    }
    $c create polygon $pts -fill $fill -outline {}
}
proc gstoreStars {c x y rating} {
    set rating [expr {double($rating)}]
    for {set i 0} {$i < 5} {incr i} {
        set fill #3a332c
        if {$rating >= ($i + 0.85)} {
            set fill #e4c4a0
        } elseif {$rating > $i} {
            set fill #a68462
        }
        gstoreStar $c [expr {$x + $i * 15 + 7}] $y 6.5 $fill
    }
    $c create text [expr {$x + 82}] $y -anchor w -text [string map {. ,} [format %.1f $rating]] -fill #e4c4a0 -font small
}
proc gstoreIconBg {kind} {
    switch $kind {
        platform { return #2f6b4f }
        race { return #8a3d2c }
        arena { return #343a86 }
        strat { return #6d5624 }
        world { return #1f6a62 }
        puzzle { return #245a7a }
        arcade { return #7a3458 }
        emu { return #3c4a32 }
        chat { return #8a5a28 }
        web { return #2e5a46 }
        mail { return #6a4030 }
        draw { return #8a4a22 }
        photo { return #3a4038 }
        model { return #4a3868 }
        audio { return #6a3052 }
        video { return #243656 }
        play { return #5c3030 }
        doc { return #4a453c }
        sheet { return #245848 }
        slides { return #6a4a28 }
        code { return #243028 }
        tool { return #3c3832 }
        lock { return #3a4034 }
        shot { return #4a3a30 }
        disk { return #2e4254 }
        ftp { return #245060 }
        music { return #5a3044 }
        default { return #3a332c }
    }
}
proc gstoreIcon {c x y sz kind} {
    set bg [gstoreIconBg $kind]
    gstoreRound $c $x $y [expr {$x + $sz}] [expr {$y + $sz}] [expr {$sz * 0.24}] -fill $bg -outline {}
    set u [expr {$sz / 48.0}]
    set f #f6f1ea
    set a #e4c4a0
    set k #1c1612
    switch $kind {
        platform {
            $c create oval [expr {$x+6*$u}] [expr {$y+30*$u}] [expr {$x+42*$u}] [expr {$y+42*$u}] -fill #173628 -outline {}
            $c create oval [expr {$x+14*$u}] [expr {$y+8*$u}] [expr {$x+32*$u}] [expr {$y+30*$u}] -fill $f -outline {}
            $c create polygon [expr {$x+28*$u}] [expr {$y+16*$u}] [expr {$x+40*$u}] [expr {$y+12*$u}] [expr {$x+32*$u}] [expr {$y+24*$u}] -fill $a -outline {}
            $c create oval [expr {$x+18*$u}] [expr {$y+14*$u}] [expr {$x+22*$u}] [expr {$y+18*$u}] -fill $k -outline {}
        }
        race {
            $c create polygon [expr {$x+8*$u}] [expr {$y+34*$u}] [expr {$x+40*$u}] [expr {$y+34*$u}] [expr {$x+34*$u}] [expr {$y+18*$u}] [expr {$x+14*$u}] [expr {$y+18*$u}] -fill $f -outline {}
            $c create oval [expr {$x+12*$u}] [expr {$y+30*$u}] [expr {$x+20*$u}] [expr {$y+38*$u}] -fill $k -outline {}
            $c create oval [expr {$x+28*$u}] [expr {$y+30*$u}] [expr {$x+36*$u}] [expr {$y+38*$u}] -fill $k -outline {}
            $c create polygon [expr {$x+16*$u}] [expr {$y+18*$u}] [expr {$x+30*$u}] [expr {$y+18*$u}] [expr {$x+26*$u}] [expr {$y+12*$u}] [expr {$x+18*$u}] [expr {$y+12*$u}] -fill $a -outline {}
        }
        arena {
            $c create oval [expr {$x+8*$u}] [expr {$y+8*$u}] [expr {$x+40*$u}] [expr {$y+40*$u}] -outline $f -width 2
            $c create oval [expr {$x+18*$u}] [expr {$y+18*$u}] [expr {$x+30*$u}] [expr {$y+30*$u}] -outline $a -width 2
            $c create line [expr {$x+24*$u}] [expr {$y+10*$u}] [expr {$x+24*$u}] [expr {$y+38*$u}] -fill $f
            $c create line [expr {$x+10*$u}] [expr {$y+24*$u}] [expr {$x+38*$u}] [expr {$y+24*$u}] -fill $f
        }
        strat {
            $c create polygon [expr {$x+24*$u}] [expr {$y+6*$u}] [expr {$x+40*$u}] [expr {$y+16*$u}] [expr {$x+40*$u}] [expr {$y+32*$u}] [expr {$x+24*$u}] [expr {$y+42*$u}] [expr {$x+8*$u}] [expr {$y+32*$u}] [expr {$x+8*$u}] [expr {$y+16*$u}] -fill $a -outline {}
            $c create polygon [expr {$x+24*$u}] [expr {$y+14*$u}] [expr {$x+32*$u}] [expr {$y+19*$u}] [expr {$x+32*$u}] [expr {$y+29*$u}] [expr {$x+24*$u}] [expr {$y+34*$u}] [expr {$x+16*$u}] [expr {$y+29*$u}] [expr {$x+16*$u}] [expr {$y+19*$u}] -fill $k -outline {}
        }
        world {
            $c create rectangle [expr {$x+8*$u}] [expr {$y+22*$u}] [expr {$x+22*$u}] [expr {$y+36*$u}] -fill #8fd0c4 -outline {}
            $c create rectangle [expr {$x+20*$u}] [expr {$y+12*$u}] [expr {$x+36*$u}] [expr {$y+28*$u}] -fill $f -outline {}
            $c create rectangle [expr {$x+16*$u}] [expr {$y+26*$u}] [expr {$x+30*$u}] [expr {$y+40*$u}] -fill $a -outline {}
        }
        puzzle {
            $c create oval [expr {$x+10*$u}] [expr {$y+16*$u}] [expr {$x+30*$u}] [expr {$y+36*$u}] -fill $f -outline {}
            $c create oval [expr {$x+22*$u}] [expr {$y+8*$u}] [expr {$x+34*$u}] [expr {$y+20*$u}] -fill $a -outline {}
            $c create oval [expr {$x+16*$u}] [expr {$y+22*$u}] [expr {$x+20*$u}] [expr {$y+26*$u}] -fill $k -outline {}
            $c create polygon [expr {$x+24*$u}] [expr {$y+30*$u}] [expr {$x+30*$u}] [expr {$y+34*$u}] [expr {$x+20*$u}] [expr {$y+34*$u}] -fill $a -outline {}
        }
        arcade {
            $c create rectangle [expr {$x+8*$u}] [expr {$y+10*$u}] [expr {$x+20*$u}] [expr {$y+18*$u}] -fill $a -outline {}
            $c create rectangle [expr {$x+22*$u}] [expr {$y+10*$u}] [expr {$x+34*$u}] [expr {$y+18*$u}] -fill $f -outline {}
            $c create rectangle [expr {$x+14*$u}] [expr {$y+20*$u}] [expr {$x+26*$u}] [expr {$y+28*$u}] -fill $f -outline {}
            $c create oval [expr {$x+18*$u}] [expr {$y+32*$u}] [expr {$x+34*$u}] [expr {$y+40*$u}] -fill $a -outline {}
        }
        emu {
            $c create rectangle [expr {$x+14*$u}] [expr {$y+8*$u}] [expr {$x+34*$u}] [expr {$y+40*$u}] -fill $k -outline {}
            $c create rectangle [expr {$x+17*$u}] [expr {$y+12*$u}] [expr {$x+31*$u}] [expr {$y+28*$u}] -fill $a -outline {}
            $c create rectangle [expr {$x+18*$u}] [expr {$y+32*$u}] [expr {$x+30*$u}] [expr {$y+35*$u}] -fill $f -outline {}
        }
        chat {
            $c create oval [expr {$x+6*$u}] [expr {$y+8*$u}] [expr {$x+30*$u}] [expr {$y+28*$u}] -fill $f -outline {}
            $c create oval [expr {$x+18*$u}] [expr {$y+20*$u}] [expr {$x+42*$u}] [expr {$y+38*$u}] -fill $a -outline {}
        }
        web {
            $c create oval [expr {$x+8*$u}] [expr {$y+8*$u}] [expr {$x+40*$u}] [expr {$y+40*$u}] -outline $f -width 2
            $c create oval [expr {$x+18*$u}] [expr {$y+8*$u}] [expr {$x+30*$u}] [expr {$y+40*$u}] -outline $f -width 2
            $c create line [expr {$x+10*$u}] [expr {$y+24*$u}] [expr {$x+38*$u}] [expr {$y+24*$u}] -fill $a -width 2
        }
        mail {
            $c create rectangle [expr {$x+8*$u}] [expr {$y+12*$u}] [expr {$x+40*$u}] [expr {$y+36*$u}] -fill $f -outline {}
            $c create polygon [expr {$x+8*$u}] [expr {$y+12*$u}] [expr {$x+24*$u}] [expr {$y+26*$u}] [expr {$x+40*$u}] [expr {$y+12*$u}] -fill $a -outline {}
        }
        draw {
            $c create line [expr {$x+12*$u}] [expr {$y+36*$u}] [expr {$x+34*$u}] [expr {$y+10*$u}] -fill $f -width [expr {max(2, int($u*4))}] -capstyle round
            $c create polygon [expr {$x+30*$u}] [expr {$y+8*$u}] [expr {$x+40*$u}] [expr {$y+12*$u}] [expr {$x+32*$u}] [expr {$y+16*$u}] -fill $a -outline {}
            $c create oval [expr {$x+8*$u}] [expr {$y+34*$u}] [expr {$x+18*$u}] [expr {$y+40*$u}] -fill $a -outline {}
        }
        photo {
            $c create rectangle [expr {$x+8*$u}] [expr {$y+12*$u}] [expr {$x+40*$u}] [expr {$y+36*$u}] -outline $f -width 2
            $c create oval [expr {$x+18*$u}] [expr {$y+16*$u}] [expr {$x+32*$u}] [expr {$y+30*$u}] -outline $a -width 2
            $c create rectangle [expr {$x+12*$u}] [expr {$y+8*$u}] [expr {$x+22*$u}] [expr {$y+14*$u}] -fill $f -outline {}
        }
        model {
            $c create polygon [expr {$x+24*$u}] [expr {$y+6*$u}] [expr {$x+40*$u}] [expr {$y+16*$u}] [expr {$x+24*$u}] [expr {$y+26*$u}] [expr {$x+8*$u}] [expr {$y+16*$u}] -fill $a -outline {}
            $c create polygon [expr {$x+8*$u}] [expr {$y+16*$u}] [expr {$x+24*$u}] [expr {$y+26*$u}] [expr {$x+24*$u}] [expr {$y+42*$u}] [expr {$x+8*$u}] [expr {$y+32*$u}] -fill $f -outline {}
            $c create polygon [expr {$x+40*$u}] [expr {$y+16*$u}] [expr {$x+24*$u}] [expr {$y+26*$u}] [expr {$x+24*$u}] [expr {$y+42*$u}] [expr {$x+40*$u}] [expr {$y+32*$u}] -fill #c4b4a4 -outline {}
        }
        audio {
            $c create rectangle [expr {$x+10*$u}] [expr {$y+20*$u}] [expr {$x+14*$u}] [expr {$y+30*$u}] -fill $f -outline {}
            $c create rectangle [expr {$x+18*$u}] [expr {$y+12*$u}] [expr {$x+22*$u}] [expr {$y+36*$u}] -fill $a -outline {}
            $c create rectangle [expr {$x+26*$u}] [expr {$y+16*$u}] [expr {$x+30*$u}] [expr {$y+34*$u}] -fill $f -outline {}
            $c create rectangle [expr {$x+34*$u}] [expr {$y+20*$u}] [expr {$x+38*$u}] [expr {$y+30*$u}] -fill $a -outline {}
        }
        video {
            $c create rectangle [expr {$x+8*$u}] [expr {$y+14*$u}] [expr {$x+40*$u}] [expr {$y+34*$u}] -fill $k -outline {}
            $c create rectangle [expr {$x+8*$u}] [expr {$y+14*$u}] [expr {$x+40*$u}] [expr {$y+20*$u}] -fill $f -outline {}
            $c create oval [expr {$x+18*$u}] [expr {$y+22*$u}] [expr {$x+30*$u}] [expr {$y+32*$u}] -fill #c4554a -outline {}
        }
        play {
            $c create polygon [expr {$x+16*$u}] [expr {$y+10*$u}] [expr {$x+16*$u}] [expr {$y+38*$u}] [expr {$x+36*$u}] [expr {$y+24*$u}] -fill $f -outline {}
        }
        doc {
            $c create polygon [expr {$x+14*$u}] [expr {$y+6*$u}] [expr {$x+30*$u}] [expr {$y+6*$u}] [expr {$x+36*$u}] [expr {$y+12*$u}] [expr {$x+36*$u}] [expr {$y+42*$u}] [expr {$x+14*$u}] [expr {$y+42*$u}] -fill $f -outline {}
            $c create rectangle [expr {$x+18*$u}] [expr {$y+18*$u}] [expr {$x+32*$u}] [expr {$y+21*$u}] -fill $k -outline {}
            $c create rectangle [expr {$x+18*$u}] [expr {$y+25*$u}] [expr {$x+30*$u}] [expr {$y+27*$u}] -fill $a -outline {}
            $c create rectangle [expr {$x+18*$u}] [expr {$y+30*$u}] [expr {$x+28*$u}] [expr {$y+32*$u}] -fill $a -outline {}
        }
        sheet {
            $c create rectangle [expr {$x+8*$u}] [expr {$y+8*$u}] [expr {$x+40*$u}] [expr {$y+40*$u}] -fill $f -outline {}
            $c create line [expr {$x+8*$u}] [expr {$y+18*$u}] [expr {$x+40*$u}] [expr {$y+18*$u}] -fill $k
            $c create line [expr {$x+8*$u}] [expr {$y+28*$u}] [expr {$x+40*$u}] [expr {$y+28*$u}] -fill $k
            $c create line [expr {$x+20*$u}] [expr {$y+8*$u}] [expr {$x+20*$u}] [expr {$y+40*$u}] -fill $a
            $c create line [expr {$x+30*$u}] [expr {$y+8*$u}] [expr {$x+30*$u}] [expr {$y+40*$u}] -fill $k
        }
        slides {
            $c create rectangle [expr {$x+6*$u}] [expr {$y+12*$u}] [expr {$x+34*$u}] [expr {$y+34*$u}] -fill $k -outline {}
            $c create rectangle [expr {$x+12*$u}] [expr {$y+8*$u}] [expr {$x+42*$u}] [expr {$y+30*$u}] -fill $f -outline {}
            $c create rectangle [expr {$x+16*$u}] [expr {$y+14*$u}] [expr {$x+34*$u}] [expr {$y+18*$u}] -fill $a -outline {}
        }
        code {
            $c create polygon [expr {$x+20*$u}] [expr {$y+8*$u}] [expr {$x+10*$u}] [expr {$y+24*$u}] [expr {$x+20*$u}] [expr {$y+40*$u}] [expr {$x+16*$u}] [expr {$y+40*$u}] [expr {$x+6*$u}] [expr {$y+24*$u}] [expr {$x+16*$u}] [expr {$y+8*$u}] -fill $a -outline {}
            $c create polygon [expr {$x+28*$u}] [expr {$y+8*$u}] [expr {$x+38*$u}] [expr {$y+24*$u}] [expr {$x+28*$u}] [expr {$y+40*$u}] [expr {$x+32*$u}] [expr {$y+40*$u}] [expr {$x+42*$u}] [expr {$y+24*$u}] [expr {$x+32*$u}] [expr {$y+8*$u}] -fill $f -outline {}
        }
        tool {
            $c create line [expr {$x+12*$u}] [expr {$y+36*$u}] [expr {$x+32*$u}] [expr {$y+16*$u}] -fill $f -width [expr {max(3, int($u*5))}] -capstyle round
            $c create oval [expr {$x+26*$u}] [expr {$y+8*$u}] [expr {$x+40*$u}] [expr {$y+22*$u}] -outline $a -width 2
        }
        lock {
            $c create rectangle [expr {$x+12*$u}] [expr {$y+20*$u}] [expr {$x+36*$u}] [expr {$y+40*$u}] -fill $f -outline {}
            $c create oval [expr {$x+16*$u}] [expr {$y+8*$u}] [expr {$x+32*$u}] [expr {$y+26*$u}] -outline $a -width 2
            $c create oval [expr {$x+21*$u}] [expr {$y+26*$u}] [expr {$x+27*$u}] [expr {$y+32*$u}] -fill $k -outline {}
        }
        shot {
            $c create rectangle [expr {$x+6*$u}] [expr {$y+16*$u}] [expr {$x+42*$u}] [expr {$y+36*$u}] -fill $k -outline {}
            $c create oval [expr {$x+16*$u}] [expr {$y+18*$u}] [expr {$x+32*$u}] [expr {$y+34*$u}] -outline $f -width 2
            $c create rectangle [expr {$x+10*$u}] [expr {$y+10*$u}] [expr {$x+22*$u}] [expr {$y+16*$u}] -fill $a -outline {}
        }
        disk {
            $c create oval [expr {$x+8*$u}] [expr {$y+8*$u}] [expr {$x+40*$u}] [expr {$y+40*$u}] -fill $f -outline {}
            $c create oval [expr {$x+18*$u}] [expr {$y+18*$u}] [expr {$x+30*$u}] [expr {$y+30*$u}] -fill $k -outline {}
            $c create rectangle [expr {$x+22*$u}] [expr {$y+6*$u}] [expr {$x+26*$u}] [expr {$y+16*$u}] -fill $a -outline {}
        }
        ftp {
            $c create polygon [expr {$x+24*$u}] [expr {$y+6*$u}] [expr {$x+36*$u}] [expr {$y+18*$u}] [expr {$x+28*$u}] [expr {$y+18*$u}] [expr {$x+28*$u}] [expr {$y+28*$u}] [expr {$x+20*$u}] [expr {$y+28*$u}] [expr {$x+20*$u}] [expr {$y+18*$u}] [expr {$x+12*$u}] [expr {$y+18*$u}] -fill $f -outline {}
            $c create polygon [expr {$x+24*$u}] [expr {$y+42*$u}] [expr {$x+12*$u}] [expr {$y+30*$u}] [expr {$x+20*$u}] [expr {$y+30*$u}] [expr {$x+20*$u}] [expr {$y+22*$u}] [expr {$x+28*$u}] [expr {$y+22*$u}] [expr {$x+28*$u}] [expr {$y+30*$u}] [expr {$x+36*$u}] [expr {$y+30*$u}] -fill $a -outline {}
        }
        music {
            $c create oval [expr {$x+10*$u}] [expr {$y+26*$u}] [expr {$x+22*$u}] [expr {$y+38*$u}] -fill $f -outline {}
            $c create line [expr {$x+20*$u}] [expr {$y+32*$u}] [expr {$x+20*$u}] [expr {$y+8*$u}] -fill $f -width 2
            $c create polygon [expr {$x+20*$u}] [expr {$y+8*$u}] [expr {$x+36*$u}] [expr {$y+12*$u}] [expr {$x+36*$u}] [expr {$y+18*$u}] [expr {$x+20*$u}] [expr {$y+14*$u}] -fill $a -outline {}
        }
        default {
            $c create oval [expr {$x+12*$u}] [expr {$y+12*$u}] [expr {$x+36*$u}] [expr {$y+36*$u}] -fill $a -outline {}
        }
    }
}
proc gstoreShot {c x y w h kind salt} {
    set x2 [expr {$x + $w}]
    set y2 [expr {$y + $h}]
    $c create rectangle $x $y $x2 $y2 -fill #100e0c -outline {}
    $c create rectangle $x $y $x2 [expr {$y+18}] -fill #2a231c -outline {}
    $c create oval [expr {$x+8}] [expr {$y+5}] [expr {$x+14}] [expr {$y+11}] -fill #c4552a -outline {}
    $c create oval [expr {$x+18}] [expr {$y+5}] [expr {$x+24}] [expr {$y+11}] -fill #e4c4a0 -outline {}
    $c create oval [expr {$x+28}] [expr {$y+5}] [expr {$x+34}] [expr {$y+11}] -fill #6a8f72 -outline {}
    set top [expr {$y + 22}]
    set bot [expr {$y2 - 8}]
    set left [expr {$x + 8}]
    set right [expr {$x2 - 8}]
    set shift [expr {($salt % 3) * ($w / 7.0)}]
    if {$h < 170} {
        gstoreShotMini $c $left $top $right $bot $kind $shift
        return
    }
    switch $kind {
        platform {
            $c create rectangle $left $top $right $bot -fill #8eb8c9 -outline {}
            $c create oval $left [expr {$bot-28}] $right [expr {$bot+10}] -fill #3e6b45 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+12}] [expr {$left+70}] [expr {$top+28}] -fill #f4f1ec -outline {}
            $c create oval [expr {$left+24+$shift}] [expr {$bot-46}] [expr {$left+46+$shift}] [expr {$bot-20}] -fill #f6f1ea -outline {}
            $c create rectangle [expr {$left+80+$shift}] [expr {$bot-18}] [expr {$left+104+$shift}] [expr {$bot-4}] -fill #c4a06a -outline {}
        }
        race {
            $c create rectangle $left $top $right $bot -fill #6a8f72 -outline {}
            $c create polygon $left $bot [expr {$left+40}] [expr {$top+10}] [expr {$right-40}] [expr {$top+10}] $right $bot -fill #4a4038 -outline {}
            $c create polygon [expr {$left+50+$shift}] [expr {$bot-8}] [expr {$left+120+$shift}] [expr {$bot-8}] [expr {$left+108+$shift}] [expr {$top+28}] [expr {$left+70+$shift}] [expr {$top+36}] -fill #f4f1ec -outline {}
            $c create oval [expr {$left+60+$shift}] [expr {$bot-16}] [expr {$left+74+$shift}] [expr {$bot-4}] -fill #1c1612 -outline {}
            $c create oval [expr {$left+100+$shift}] [expr {$bot-16}] [expr {$left+114+$shift}] [expr {$bot-4}] -fill #1c1612 -outline {}
        }
        arena {
            $c create rectangle $left $top $right $bot -fill #1a1e2e -outline {}
            $c create line [expr {$left+20}] $top [expr {$right-30}] $bot -fill #3a4266
            $c create line [expr {$right-20}] $top [expr {$left+40}] $bot -fill #3a4266
            set cx [expr {$left + $w * 0.45 + $shift * 0.2}]
            set cy [expr {($top + $bot) / 2.0}]
            $c create oval [expr {$cx-16}] [expr {$cy-16}] [expr {$cx+16}] [expr {$cy+16}] -outline #e4c4a0 -width 2
            $c create line [expr {$cx-26}] $cy [expr {$cx+26}] $cy -fill #e4c4a0
            $c create line $cx [expr {$cy-26}] $cx [expr {$cy+26}] -fill #e4c4a0
        }
        strat {
            $c create rectangle $left $top $right $bot -fill #c4b48a -outline {}
            $c create polygon [expr {$left+20}] [expr {$top+20}] [expr {$left+80}] [expr {$top+8}] [expr {$left+120}] [expr {$bot-20}] [expr {$left+30}] [expr {$bot-10}] -fill #6a8f72 -outline {}
            $c create rectangle [expr {$left+90+$shift}] [expr {$top+24}] [expr {$left+150+$shift}] [expr {$top+70}] -fill #8a3d2c -outline {}
            $c create oval [expr {$right-70}] [expr {$bot-40}] [expr {$right-24}] [expr {$bot-8}] -fill #3d6e9a -outline {}
        }
        world {
            $c create rectangle $left $top $right $bot -fill #87c0c4 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$bot-36}] [expr {$left+48}] [expr {$bot-8}] -fill #d8efe8 -outline {}
            $c create rectangle [expr {$left+40+$shift}] [expr {$bot-58}] [expr {$left+78+$shift}] [expr {$bot-20}] -fill #f4f1ec -outline {}
            $c create rectangle [expr {$left+70+$shift}] [expr {$bot-40}] [expr {$left+108+$shift}] [expr {$bot-8}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$right-60}] [expr {$top+16}] [expr {$right-16}] [expr {$top+36}] -fill #f6f1ea -outline {}
        }
        puzzle {
            $c create rectangle $left $top $right $bot -fill #d7e4ea -outline {}
            $c create rectangle [expr {$left+20}] [expr {$bot-16}] [expr {$right-20}] [expr {$bot-6}] -fill #6a8f72 -outline {}
            $c create oval [expr {$left+24+$shift}] [expr {$top+20}] [expr {$left+48+$shift}] [expr {$top+44}] -fill #f6f1ea -outline {}
            $c create oval [expr {$left+70+$shift}] [expr {$top+36}] [expr {$left+94+$shift}] [expr {$top+60}] -fill #f6f1ea -outline {}
            $c create oval [expr {$left+120}] [expr {$bot-48}] [expr {$left+144}] [expr {$bot-24}] -fill #e4c4a0 -outline {}
        }
        arcade {
            $c create rectangle $left $top $right $bot -fill #1c1612 -outline {}
            set bx $left
            set row 0
            while {$bx < $right - 20} {
                set col [expr {($row + $salt) % 3}]
                if {$col == 0} { set fill #e4c4a0 } elseif {$col == 1} { set fill #c4552a } else { set fill #f4f1ec }
                $c create rectangle $bx [expr {$top+8}] [expr {$bx+22}] [expr {$top+20}] -fill $fill -outline {}
                set bx [expr {$bx + 26}]
                incr row
            }
            $c create oval [expr {$left+40+$shift}] [expr {$bot-28}] [expr {$left+92+$shift}] [expr {$bot-16}] -fill #e4c4a0 -outline {}
            $c create oval [expr {$left+80+$shift}] [expr {$bot-16}] [expr {$left+92+$shift}] [expr {$bot-6}] -fill #f4f1ec -outline {}
        }
        emu {
            $c create rectangle $left $top $right $bot -fill #14181c -outline {}
            $c create rectangle [expr {$left+24}] [expr {$top+16}] [expr {$right-24}] [expr {$bot-16}] -fill #0e2a22 -outline #e4c4a0
            $c create text [expr {($left+$right)/2.0}] [expr {($top+$bot)/2.0}] -text "PLAY" -fill #e4c4a0 -font small
            $c create rectangle [expr {$left+8}] [expr {$bot-14}] [expr {$left+40+$shift}] [expr {$bot-6}] -fill #3a332c -outline {}
        }
        chat {
            $c create rectangle $left $top $right $bot -fill #1c1814 -outline {}
            $c create rectangle $left $top [expr {$left+52}] $bot -fill #2a231c -outline {}
            $c create oval [expr {$left+70}] [expr {$top+16}] [expr {$left+150+$shift}] [expr {$top+42}] -fill #e4c4a0 -outline {}
            $c create oval [expr {$left+110}] [expr {$top+52}] [expr {$right-16}] [expr {$top+78}] -fill #f4f1ec -outline {}
            $c create oval [expr {$left+70}] [expr {$top+88}] [expr {$left+180}] [expr {$top+112}] -fill #e4c4a0 -outline {}
        }
        web {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create rectangle $left $top $right [expr {$top+22}] -fill #e7d3bb -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+6}] [expr {$left+120+$shift}] [expr {$top+16}] -fill #ffffff -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+36}] [expr {$right-16}] [expr {$top+52}] -fill #1c1612 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+64}] [expr {$left+$w*0.55}] [expr {$bot-12}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+$w*0.62}] [expr {$top+64}] [expr {$right-16}] [expr {$bot-12}] -fill #d9cfc3 -outline {}
        }
        mail {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create rectangle $left $top [expr {$left+70}] $bot -fill #2a231c -outline {}
            $c create rectangle [expr {$left+84}] [expr {$top+14}] [expr {$right-12}] [expr {$top+36}] -fill #ffffff -outline {}
            $c create rectangle [expr {$left+84}] [expr {$top+44}] [expr {$right-12}] [expr {$top+78}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+84}] [expr {$top+86}] [expr {$left+160}] [expr {$top+104}] -fill #ffffff -outline {}
        }
        draw {
            $c create rectangle $left $top $right $bot -fill #d5cfc6 -outline {}
            $c create rectangle $left $top [expr {$left+28}] $bot -fill #2a231c -outline {}
            $c create rectangle [expr {$right-24}] $top $right $bot -fill #2a231c -outline {}
            $c create oval [expr {$left+50+$shift}] [expr {$top+18}] [expr {$left+120+$shift}] [expr {$bot-16}] -outline #1c1612 -width 2
            $c create line [expr {$left+70}] [expr {$top+20}] [expr {$right-40}] [expr {$bot-20}] -fill #c4552a -width 3
        }
        photo {
            $c create rectangle $left $top $right $bot -fill #161614 -outline {}
            $c create rectangle [expr {$left+20}] [expr {$top+12}] [expr {$right-20}] [expr {$bot-12}] -fill #3a342c -outline {}
            $c create oval [expr {$left+40+$shift}] [expr {$top+24}] [expr {$left+100+$shift}] [expr {$bot-24}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$right-70}] [expr {$top+20}] [expr {$right-28}] [expr {$bot-20}] -fill #6a8f72 -outline {}
        }
        model {
            $c create rectangle $left $top $right $bot -fill #2a3138 -outline {}
            set cx [expr {$left + $w * 0.42}]
            set cy [expr {$top + ($bot-$top) * 0.42}]
            $c create polygon $cx [expr {$cy-30}] [expr {$cx+46}] $cy $cx [expr {$cy+24}] [expr {$cx-46}] $cy -fill #e4c4a0 -outline {}
            $c create polygon [expr {$cx-46}] $cy $cx [expr {$cy+24}] $cx [expr {$cy+70}] [expr {$cx-46}] [expr {$cy+40}] -fill #f4f1ec -outline {}
            $c create polygon [expr {$cx+46}] $cy $cx [expr {$cy+24}] $cx [expr {$cy+70}] [expr {$cx+46}] [expr {$cy+40}] -fill #b7a898 -outline {}
        }
        audio {
            $c create rectangle $left $top $right $bot -fill #1a1618 -outline {}
            set bx [expr {$left + 16}]
            set n 0
            while {$bx < $right - 16} {
                set hh [expr {18 + (($n + $salt) % 5) * 10}]
                $c create rectangle $bx [expr {$bot - $hh}] [expr {$bx+8}] [expr {$bot-8}] -fill #e4c4a0 -outline {}
                set bx [expr {$bx + 14}]
                incr n
            }
        }
        video {
            $c create rectangle $left $top $right $bot -fill #101418 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+12}] [expr {$right-16}] [expr {$bot-28}] -fill #1c2838 -outline {}
            $c create oval [expr {$left+$w*0.42}] [expr {$top+36}] [expr {$left+$w*0.42+28}] [expr {$top+64}] -fill #c4554a -outline {}
            $c create rectangle $left [expr {$bot-22}] $right $bot -fill #2a231c -outline {}
        }
        play {
            $c create rectangle $left $top $right $bot -fill #101010 -outline {}
            set cx [expr {($left+$right)/2.0}]
            set cy [expr {($top+$bot)/2.0}]
            $c create polygon [expr {$cx-16}] [expr {$cy-22}] [expr {$cx-16}] [expr {$cy+22}] [expr {$cx+22}] $cy -fill #e4c4a0 -outline {}
            $c create rectangle $left [expr {$bot-16}] $right [expr {$bot-8}] -fill #3a332c -outline {}
            $c create rectangle $left [expr {$bot-16}] [expr {$left+40+$shift}] [expr {$bot-8}] -fill #e4c4a0 -outline {}
        }
        doc {
            $c create rectangle $left $top $right $bot -fill #e7e0d6 -outline {}
            $c create rectangle [expr {$left+$w*0.22}] [expr {$top+8}] [expr {$right-$w*0.22}] $bot -fill #f7f3ec -outline {}
            $c create rectangle [expr {$left+$w*0.28}] [expr {$top+20}] [expr {$right-$w*0.28}] [expr {$top+28}] -fill #1c1612 -outline {}
            $c create rectangle [expr {$left+$w*0.28}] [expr {$top+36}] [expr {$right-$w*0.30}] [expr {$top+42}] -fill #c8bfb4 -outline {}
            $c create rectangle [expr {$left+$w*0.28}] [expr {$top+48}] [expr {$right-$w*0.36}] [expr {$top+54}] -fill #c8bfb4 -outline {}
            $c create rectangle [expr {$left+$w*0.28}] [expr {$top+60}] [expr {$left+$w*0.55}] [expr {$top+66}] -fill #e4c4a0 -outline {}
        }
        sheet {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            set gy $top
            while {$gy < $bot} {
                $c create line $left $gy $right $gy -fill #d5cfc6
                set gy [expr {$gy + 16}]
            }
            set gx $left
            while {$gx < $right} {
                $c create line $gx $top $gx $bot -fill #d5cfc6
                set gx [expr {$gx + 28}]
            }
            $c create rectangle [expr {$left+28}] [expr {$top+16}] [expr {$left+84}] [expr {$top+32}] -fill #e4c4a0 -outline {}
        }
        slides {
            $c create rectangle $left $top $right $bot -fill #2a231c -outline {}
            $c create rectangle [expr {$left+18}] [expr {$top+10}] [expr {$right-18}] [expr {$bot-10}] -fill #f7f3ec -outline {}
            $c create rectangle [expr {$left+32}] [expr {$top+24}] [expr {$left+120+$shift}] [expr {$top+40}] -fill #1c1612 -outline {}
            $c create oval [expr {$right-80}] [expr {$top+48}] [expr {$right-36}] [expr {$bot-16}] -fill #e4c4a0 -outline {}
        }
        code {
            $c create rectangle $left $top $right $bot -fill #14201c -outline {}
            $c create rectangle [expr {$left+12}] [expr {$top+10}] [expr {$left+40}] [expr {$top+16}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+28}] [expr {$top+24}] [expr {$left+110}] [expr {$top+30}] -fill #9dcec2 -outline {}
            $c create rectangle [expr {$left+28}] [expr {$top+38}] [expr {$left+90+$shift}] [expr {$top+44}] -fill #f4f1ec -outline {}
            $c create rectangle [expr {$left+12}] [expr {$top+52}] [expr {$left+70}] [expr {$top+58}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+28}] [expr {$top+66}] [expr {$left+130}] [expr {$top+72}] -fill #9dcec2 -outline {}
        }
        tool {
            $c create rectangle $left $top $right $bot -fill #1c1916 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+16}] [expr {$right-16}] [expr {$top+40}] -fill #2a231c -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+48}] [expr {$left+80+$shift}] [expr {$top+62}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+70}] [expr {$right-40}] [expr {$top+84}] -fill #3a332c -outline {}
        }
        lock {
            $c create rectangle $left $top $right $bot -fill #171c18 -outline {}
            $c create rectangle [expr {$left+24}] [expr {$top+20}] [expr {$right-24}] [expr {$bot-16}] -fill #243028 -outline {}
            $c create rectangle [expr {$left+36}] [expr {$top+36}] [expr {$left+120}] [expr {$top+48}] -fill #1c1612 -outline {}
            $c create oval [expr {$right-48}] [expr {$top+34}] [expr {$right-32}] [expr {$top+50}] -fill #e4c4a0 -outline {}
        }
        shot {
            $c create rectangle $left $top $right $bot -fill #e7d3bb -outline {}
            $c create rectangle [expr {$left+20}] [expr {$top+16}] [expr {$right-20}] [expr {$bot-16}] -fill #1c1612 -outline #f4f1ec
            $c create rectangle [expr {$left+36}] [expr {$bot-28}] [expr {$left+90+$shift}] [expr {$bot-22}] -fill #e4c4a0 -outline {}
        }
        disk {
            $c create rectangle $left $top $right $bot -fill #12181e -outline {}
            $c create rectangle [expr {$left+20}] [expr {$top+20}] [expr {$left+$w*0.46}] [expr {$bot-20}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+$w*0.46}] [expr {$top+20}] [expr {$left+$w*0.72}] [expr {$bot-20}] -fill #6a8f72 -outline {}
            $c create rectangle [expr {$left+$w*0.72}] [expr {$top+20}] [expr {$right-16}] [expr {$bot-20}] -fill #3a332c -outline {}
        }
        ftp {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create rectangle $left $top [expr {$left+$w*0.48}] $bot -fill #ffffff -outline {}
            $c create rectangle [expr {$left+12}] [expr {$top+16}] [expr {$left+80}] [expr {$top+28}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+12}] [expr {$top+36}] [expr {$left+100}] [expr {$top+46}] -fill #d9cfc3 -outline {}
            $c create polygon [expr {$right-36}] [expr {$top+40}] [expr {$right-16}] [expr {($top+$bot)/2.0}] [expr {$right-36}] [expr {$bot-24}] -fill #1c1612 -outline {}
        }
        music {
            $c create rectangle $left $top $right $bot -fill #1a1418 -outline {}
            $c create rectangle $left $top [expr {$left+64}] $bot -fill #2a2024 -outline {}
            $c create rectangle [expr {$left+78}] [expr {$top+14}] [expr {$right-16}] [expr {$top+36}] -fill #3a2a30 -outline {}
            $c create rectangle [expr {$left+78}] [expr {$top+14}] [expr {$left+78+$w*0.25+$shift}] [expr {$top+36}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+78}] [expr {$top+48}] [expr {$right-16}] [expr {$top+64}] -fill #3a2a30 -outline {}
            $c create rectangle [expr {$left+78}] [expr {$top+72}] [expr {$right-40}] [expr {$top+88}] -fill #3a2a30 -outline {}
        }
        default {
            $c create rectangle $left $top $right $bot -fill #241e18 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+16}] [expr {$right-16}] [expr {$top+36}] -fill #e4c4a0 -outline {}
        }
    }
}
proc gstoreShotMini {c left top right bot kind shift} {
    set mid [expr {($top + $bot) / 2.0}]
    switch $kind {
        platform {
            $c create rectangle $left $top $right $bot -fill #8eb8c9 -outline {}
            $c create oval $left [expr {$bot-18}] $right [expr {$bot+8}] -fill #3e6b45 -outline {}
            $c create oval [expr {$left+18+$shift}] [expr {$top+8}] [expr {$left+40+$shift}] [expr {$bot-8}] -fill #f6f1ea -outline {}
        }
        race {
            $c create rectangle $left $top $right $bot -fill #6a8f72 -outline {}
            $c create polygon $left $bot [expr {$left+30}] $top [expr {$right-20}] $top $right $bot -fill #4a4038 -outline {}
            $c create polygon [expr {$left+36+$shift}] [expr {$bot-4}] [expr {$left+90+$shift}] [expr {$bot-4}] [expr {$left+78+$shift}] [expr {$top+8}] [expr {$left+48+$shift}] [expr {$top+14}] -fill #f4f1ec -outline {}
        }
        arena {
            $c create rectangle $left $top $right $bot -fill #1a1e2e -outline {}
            set cx [expr {$left + ($right-$left) * 0.5}]
            $c create oval [expr {$cx-14}] [expr {$mid-14}] [expr {$cx+14}] [expr {$mid+14}] -outline #e4c4a0 -width 2
            $c create line [expr {$cx-24}] $mid [expr {$cx+24}] $mid -fill #e4c4a0
            $c create line $cx [expr {$mid-18}] $cx [expr {$mid+18}] -fill #e4c4a0
        }
        strat {
            $c create rectangle $left $top $right $bot -fill #c4b48a -outline {}
            $c create polygon [expr {$left+10}] $top [expr {$left+70}] [expr {$top+6}] [expr {$left+90}] $bot [expr {$left+16}] $bot -fill #6a8f72 -outline {}
            $c create rectangle [expr {$left+80+$shift}] [expr {$top+8}] [expr {$left+120+$shift}] [expr {$bot-8}] -fill #8a3d2c -outline {}
        }
        world {
            $c create rectangle $left $top $right $bot -fill #87c0c4 -outline {}
            $c create rectangle [expr {$left+12+$shift}] [expr {$mid-8}] [expr {$left+36+$shift}] [expr {$bot-4}] -fill #f4f1ec -outline {}
            $c create rectangle [expr {$left+32+$shift}] [expr {$mid-18}] [expr {$left+58+$shift}] [expr {$bot-10}] -fill #e4c4a0 -outline {}
        }
        puzzle {
            $c create rectangle $left $top $right $bot -fill #d7e4ea -outline {}
            $c create oval [expr {$left+16+$shift}] [expr {$top+6}] [expr {$left+36+$shift}] [expr {$bot-8}] -fill #f6f1ea -outline {}
            $c create oval [expr {$left+48+$shift}] [expr {$top+10}] [expr {$left+68+$shift}] [expr {$bot-6}] -fill #e4c4a0 -outline {}
        }
        arcade {
            $c create rectangle $left $top $right $bot -fill #1c1612 -outline {}
            $c create rectangle [expr {$left+10}] [expr {$top+6}] [expr {$left+28}] [expr {$top+16}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+32}] [expr {$top+6}] [expr {$left+50}] [expr {$top+16}] -fill #f4f1ec -outline {}
            $c create rectangle [expr {$left+54}] [expr {$top+6}] [expr {$left+72}] [expr {$top+16}] -fill #c4552a -outline {}
            $c create oval [expr {$left+30+$shift}] [expr {$bot-14}] [expr {$left+70+$shift}] [expr {$bot-4}] -fill #e4c4a0 -outline {}
        }
        emu {
            $c create rectangle $left $top $right $bot -fill #14181c -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+6}] [expr {$right-16}] [expr {$bot-6}] -fill #0e2a22 -outline #e4c4a0
        }
        chat {
            $c create rectangle $left $top $right $bot -fill #1c1814 -outline {}
            $c create oval [expr {$left+12}] [expr {$top+6}] [expr {$left+80+$shift}] [expr {$mid}] -fill #e4c4a0 -outline {}
            $c create oval [expr {$left+40}] [expr {$mid-2}] [expr {$right-10}] [expr {$bot-4}] -fill #f4f1ec -outline {}
        }
        web {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create rectangle $left $top $right [expr {$top+14}] -fill #e7d3bb -outline {}
            $c create rectangle [expr {$left+10}] [expr {$top+18}] [expr {$left+70+$shift}] [expr {$bot-6}] -fill #e4c4a0 -outline {}
        }
        mail {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create rectangle [expr {$left+10}] [expr {$top+8}] [expr {$right-10}] [expr {$mid}] -fill #ffffff -outline {}
            $c create polygon [expr {$left+10}] [expr {$top+8}] [expr {($left+$right)/2.0}] $mid [expr {$right-10}] [expr {$top+8}] -fill #e4c4a0 -outline {}
        }
        draw {
            $c create rectangle $left $top $right $bot -fill #d5cfc6 -outline {}
            $c create rectangle $left $top [expr {$left+16}] $bot -fill #2a231c -outline {}
            $c create oval [expr {$left+28+$shift}] [expr {$top+6}] [expr {$left+70+$shift}] [expr {$bot-4}] -outline #1c1612 -width 2
        }
        photo {
            $c create rectangle $left $top $right $bot -fill #161614 -outline {}
            $c create oval [expr {$left+20+$shift}] [expr {$top+6}] [expr {$left+64+$shift}] [expr {$bot-4}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$right-40}] [expr {$top+8}] [expr {$right-10}] [expr {$bot-6}] -fill #6a8f72 -outline {}
        }
        model {
            $c create rectangle $left $top $right $bot -fill #2a3138 -outline {}
            set cx [expr {$left + ($right-$left) * 0.45}]
            $c create polygon $cx [expr {$top+4}] [expr {$cx+28}] $mid $cx [expr {$bot-4}] [expr {$cx-28}] $mid -fill #e4c4a0 -outline {}
        }
        audio {
            $c create rectangle $left $top $right $bot -fill #1a1618 -outline {}
            set bx [expr {$left + 8}]
            set n 0
            while {$bx < $right - 10} {
                set hh [expr {8 + (($n + int($shift)) % 4) * 6}]
                $c create rectangle $bx [expr {$bot - $hh}] [expr {$bx+6}] [expr {$bot-4}] -fill #e4c4a0 -outline {}
                set bx [expr {$bx + 10}]
                incr n
            }
        }
        video {
            $c create rectangle $left $top $right $bot -fill #101418 -outline {}
            $c create oval [expr {$left+($right-$left)*0.4}] [expr {$mid-10}] [expr {$left+($right-$left)*0.4+22}] [expr {$mid+10}] -fill #c4554a -outline {}
        }
        play {
            $c create rectangle $left $top $right $bot -fill #101010 -outline {}
            set cx [expr {($left+$right)/2.0}]
            $c create polygon [expr {$cx-10}] [expr {$mid-12}] [expr {$cx-10}] [expr {$mid+12}] [expr {$cx+14}] $mid -fill #e4c4a0 -outline {}
        }
        doc {
            $c create rectangle $left $top $right $bot -fill #e7e0d6 -outline {}
            $c create rectangle [expr {$left+24}] [expr {$top+4}] [expr {$right-24}] $bot -fill #f7f3ec -outline {}
            $c create rectangle [expr {$left+34}] [expr {$top+10}] [expr {$right-34}] [expr {$top+16}] -fill #1c1612 -outline {}
        }
        sheet {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create line $left $mid $right $mid -fill #d5cfc6
            $c create line [expr {($left+$right)/2.0}] $top [expr {($left+$right)/2.0}] $bot -fill #e4c4a0
        }
        slides {
            $c create rectangle $left $top $right $bot -fill #2a231c -outline {}
            $c create rectangle [expr {$left+12}] [expr {$top+4}] [expr {$right-12}] [expr {$bot-4}] -fill #f7f3ec -outline {}
            $c create rectangle [expr {$left+20}] [expr {$top+10}] [expr {$left+70}] [expr {$top+18}] -fill #1c1612 -outline {}
        }
        code {
            $c create rectangle $left $top $right $bot -fill #14201c -outline {}
            $c create rectangle [expr {$left+10}] [expr {$top+8}] [expr {$left+36}] [expr {$top+12}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+18}] [expr {$top+18}] [expr {$left+80}] [expr {$top+22}] -fill #9dcec2 -outline {}
            $c create rectangle [expr {$left+18}] [expr {$mid+4}] [expr {$left+60+$shift}] [expr {$mid+8}] -fill #f4f1ec -outline {}
        }
        tool {
            $c create rectangle $left $top $right $bot -fill #1c1916 -outline {}
            $c create rectangle [expr {$left+10}] [expr {$top+8}] [expr {$right-10}] [expr {$mid}] -fill #2a231c -outline {}
            $c create rectangle [expr {$left+10}] [expr {$mid+6}] [expr {$left+50+$shift}] [expr {$bot-6}] -fill #e4c4a0 -outline {}
        }
        lock {
            $c create rectangle $left $top $right $bot -fill #171c18 -outline {}
            $c create rectangle [expr {$left+16}] [expr {$top+8}] [expr {$right-16}] [expr {$bot-6}] -fill #243028 -outline {}
            $c create oval [expr {$right-36}] [expr {$mid-6}] [expr {$right-24}] [expr {$mid+6}] -fill #e4c4a0 -outline {}
        }
        shot {
            $c create rectangle $left $top $right $bot -fill #e7d3bb -outline {}
            $c create rectangle [expr {$left+14}] [expr {$top+6}] [expr {$right-14}] [expr {$bot-6}] -outline #1c1612 -width 2
        }
        disk {
            $c create rectangle $left $top $right $bot -fill #12181e -outline {}
            $c create rectangle [expr {$left+8}] [expr {$top+8}] [expr {$left+($right-$left)*0.5}] [expr {$bot-6}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+($right-$left)*0.5}] [expr {$top+8}] [expr {$right-8}] [expr {$bot-6}] -fill #6a8f72 -outline {}
        }
        ftp {
            $c create rectangle $left $top $right $bot -fill #f3efe8 -outline {}
            $c create polygon [expr {$left+20}] [expr {$top+6}] [expr {$left+36}] $mid [expr {$left+20}] [expr {$bot-4}] [expr {$left+8}] $mid -fill #1c1612 -outline {}
            $c create polygon [expr {$right-20}] [expr {$bot-4}] [expr {$right-36}] $mid [expr {$right-20}] [expr {$top+6}] [expr {$right-8}] $mid -fill #e4c4a0 -outline {}
        }
        music {
            $c create rectangle $left $top $right $bot -fill #1a1418 -outline {}
            $c create rectangle [expr {$left+10}] [expr {$top+8}] [expr {$left+10+$shift+40}] [expr {$mid}] -fill #e4c4a0 -outline {}
            $c create rectangle [expr {$left+10}] [expr {$mid+6}] [expr {$right-16}] [expr {$bot-6}] -fill #3a2a30 -outline {}
        }
        default {
            $c create rectangle $left $top $right $bot -fill #241e18 -outline {}
        }
    }
}
proc gstorePage {name} {
    set ::gstorePage $name
    set ::gstorePick ""
    set ::gstoreW 0
    set e .wgstore.in.b.main.top.box.q
    if {[winfo exists $e]} { $e delete 0 end }
    gstoreSearchChanged
}
proc gstoreBack {} {
    if {[info exists ::gstoreFrom] && $::gstoreFrom eq "search"} {
        set ::gstorePage home
        set ::gstorePick ""
        set ::gstoreW 0
        gstoreMark
        gstoreRender
        return
    }
    if {[info exists ::gstoreFrom] && $::gstoreFrom ne "" && $::gstoreFrom ne "detail"} {
        gstorePage $::gstoreFrom
    } else {
        gstorePage home
    }
}
proc gstoreMark {} {
    if {![info exists ::gstorePage]} { set ::gstorePage home }
    foreach id {home games talk art apps} {
        set w .wgstore.in.b.nav.$id
        if {![winfo exists $w]} continue
        if {$id eq $::gstorePage} {
            $w configure -bg #2a231c
            $w.bar configure -bg #e4c4a0
            $w.t configure -bg #2a231c -fg #e4c4a0
        } else {
            $w configure -bg #141210
            $w.bar configure -bg #141210
            $w.t configure -bg #141210 -fg #f4f1ec
        }
    }
}
proc gstoreQuery {} {
    if {![winfo exists .wgstore.in.b.main.top.box.q]} { return "" }
    return [string trim [.wgstore.in.b.main.top.box.q get]]
}
proc gstoreSearchChanged {} {
    set ::gstoreW 0
    gstoreRender
}
proc gstoreHit {row q} {
    if {$q eq ""} { return 1 }
    set title [lindex $row 1]
    set blurb [lindex $row 4]
    set cat [gstoreCatName [lindex $row 0]]
    set blob [string tolower "$title $blurb $cat"]
    set qq [string tolower $q]
    set qq [string map {* \* ? \? [ \[ ] \]} $qq]
    return [string match *$qq* $blob]
}
proc gstoreCatName {cat} {
    switch $cat {
        games { return "Игры" }
        talk { return "Общение" }
        net { return "Интернет" }
        art { return "Творчество" }
        tool { return "Программы" }
        default { return "Программа" }
    }
}
proc gstoreBtnLabel {pkg app} {
    if {$app eq "none"} { return "Нет в каталоге" }
    if {$app ne "bin" || [gstoreInstalled $pkg]} { return "Открыть" }
    if {![info exists ::gstoreReady] || !$::gstoreReady} { return "..." }
    return "Установить"
}
proc gstoreTake {cat n} {
    set out {}
    foreach row [gstoreCatalog] {
        if {[lindex $row 0] ne $cat} continue
        lappend out $row
        if {[llength $out] >= $n} break
    }
    return $out
}
proc gstoreByCat {cat} {
    set out {}
    foreach row [gstoreCatalog] {
        if {$cat eq "apps"} {
            if {[lindex $row 0] eq "games" || [lindex $row 0] eq "talk" || [lindex $row 0] eq "art"} continue
        } elseif {[lindex $row 0] ne $cat} {
            continue
        }
        lappend out $row
    }
    return $out
}
proc gstoreFind {title} {
    foreach row [gstoreCatalog] {
        if {[lindex $row 1] eq $title} { return $row }
    }
    return {}
}
proc gstoreShort {title n} {
    if {[string length $title] <= $n} { return $title }
    return "[string range $title 0 [expr {$n - 2}]]..."
}
proc gstoreTag {} {
    if {![info exists ::gstoreSeq]} { set ::gstoreSeq 0 }
    incr ::gstoreSeq
    return t$::gstoreSeq
}
proc gstoreDetail {row} {
    if {![info exists ::gstorePage]} { set ::gstorePage home }
    if {[gstoreQuery] ne ""} {
        set ::gstoreFrom search
    } elseif {$::gstorePage ne "detail"} {
        set ::gstoreFrom $::gstorePage
    }
    set ::gstorePick $row
    set ::gstorePage detail
    set ::gstoreW 0
    gstoreMark
    gstoreRender
}
proc gstoreCard {c x y row wide} {
    lassign $row cat title pkg app blurb kind rating
    set tag [gstoreTag]
    set cw 236
    set ch 168
    set sh 92
    gstoreRound $c $x $y [expr {$x+$cw}] [expr {$y+$ch}] 12 -fill #221f1c -tags $tag
    gstoreShot $c [expr {$x+12}] [expr {$y+12}] [expr {$cw-24}] $sh $kind [string length $title]
    set iy [expr {$y + $sh + 20}]
    gstoreIcon $c [expr {$x+12}] $iy 40 $kind
    $c create text [expr {$x+60}] [expr {$iy+10}] -anchor w -text [gstoreShort $title 16] -fill #f4f1ec -font ui -tags $tag
    gstoreStars $c [expr {$x+60}] [expr {$iy+28}] $rating
    $c create rectangle $x $y [expr {$x+$cw}] [expr {$y+$ch}] -fill {} -outline {} -tags $tag
    $c bind $tag <Button-1> [list gstoreDetail $row]
    $c bind $tag <Enter> [list $c configure -cursor hand2]
    $c bind $tag <Leave> [list $c configure -cursor {}]
    return $cw
}
proc gstoreShelf {c y head page rows} {
    set w [winfo width $c]
    set tag [gstoreTag]
    $c create text 28 $y -anchor w -text $head -fill #f4f1ec -font uib
    $c create text [expr {$w-28}] $y -anchor e -text "Все" -fill #e4c4a0 -font small -tags $tag
    $c bind $tag <Button-1> [list gstorePage $page]
    $c bind $tag <Enter> [list $c configure -cursor hand2]
    $c bind $tag <Leave> [list $c configure -cursor {}]
    set y [expr {$y + 18}]
    set x 28
    foreach row $rows {
        if {$x + 236 > $w - 8} break
        set cw [gstoreCard $c $x $y $row 0]
        set x [expr {$x + $cw + 14}]
    }
    return [expr {$y + 182}]
}
proc gstoreGrid {c y rows} {
    set w [winfo width $c]
    set x 28
    set maxy $y
    foreach row $rows {
        if {$x + 236 > $w - 8} {
            set x 28
            set y [expr {$y + 182}]
        }
        gstoreCard $c $x $y $row 0
        set x [expr {$x + 250}]
        set maxy $y
    }
    return [expr {$maxy + 182}]
}
proc gstoreRender {} {
    gstoreFonts
    set c .wgstore.in.b.main.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} { after 80 gstoreRender; return }
    $c delete all
    if {![info exists ::gstorePage]} { set ::gstorePage home }
    set q [gstoreQuery]
    if {$q ne ""} {
        $c create text 28 24 -anchor w -text "Поиск: $q" -fill #f4f1ec -font uib
        set hits {}
        foreach row [gstoreCatalog] {
            if {[gstoreHit $row $q]} { lappend hits $row }
        }
        if {[llength $hits] == 0} {
            $c create text 28 70 -anchor w -text "Ничего не нашлось" -fill #a3988c -font ui
            $c configure -scrollregion [list 0 0 $w 200]
            return
        }
        set y [gstoreGrid $c 56 $hits]
        $c configure -scrollregion [list 0 0 $w $y]
        return
    }
    if {$::gstorePage eq "detail" && [info exists ::gstorePick] && [llength $::gstorePick] >= 7} {
        lassign $::gstorePick cat title pkg app blurb kind rating
        set tag [gstoreTag]
        $c create text 28 22 -anchor w -text "Назад" -fill #e4c4a0 -font ui -tags $tag
        $c bind $tag <Button-1> gstoreBack
        $c bind $tag <Enter> [list $c configure -cursor hand2]
        $c bind $tag <Leave> [list $c configure -cursor {}]
        gstoreIcon $c 28 52 84 $kind
        $c create text 128 62 -anchor w -text $title -fill #f4f1ec -font storehero
        $c create text 128 108 -anchor w -text [gstoreCatName $cat] -fill #a3988c -font small
        gstoreStars $c 128 136 $rating
        $c create text 28 168 -anchor w -text $blurb -fill #f4f1ec -font ui -width [expr {max(200, $w - 56)}]
        set label [gstoreBtnLabel $pkg $app]
        set go [gstoreTag]
        gstoreRound $c 28 214 236 262 12 -fill #e4c4a0 -tags $go
        $c create text 132 238 -text $label -fill #1c1612 -font uib -tags $go
        $c bind $go <Button-1> [list gstoreAct $title $pkg $app]
        $c bind $go <Enter> [list $c configure -cursor hand2]
        $c bind $go <Leave> [list $c configure -cursor {}]
        $c create text 28 292 -anchor w -text "Окно программы" -fill #f4f1ec -font uib
        set gap 16
        set sw [expr {($w - 56 - $gap) / 2.0}]
        if {$sw < 180} { set sw [expr {$w - 56}] }
        gstoreShot $c 28 318 $sw 210 $kind 0
        if {$sw > 200 && ($w - 56) > ($sw + $gap + 180)} {
            gstoreShot $c [expr {28 + $sw + $gap}] 318 $sw 210 $kind 2
        }
        $c configure -scrollregion [list 0 0 $w 560]
        return
    }
    if {$::gstorePage eq "home"} {
        set x2 [expr {$w - 16}]
        gstoreRound $c 16 12 $x2 250 18 -fill #1c1612 -outline {}
        $c create text 44 36 -anchor w -text "G-Store" -fill #e4c4a0 -font small
        $c create text 44 78 -anchor w -text "Программы этого стола" -fill #f6f1ea -font storehero
        $c create text 44 122 -anchor w -text "Игры, общение, рисунок и музыка." -fill #f4f1ec -font storesub
        $c create text 44 148 -anchor w -text "Ставятся сюда и открываются в своём окне." -fill #a3988c -font small
        set hero [gstoreTag]
        gstoreRound $c 44 176 196 220 12 -fill #e4c4a0 -tags $hero
        $c create text 120 198 -text "К играм" -fill #1c1612 -font uib -tags $hero
        $c bind $hero <Button-1> { gstorePage games }
        $c bind $hero <Enter> [list $c configure -cursor hand2]
        $c bind $hero <Leave> [list $c configure -cursor {}]
        if {$w > 920} {
            gstoreShot $c [expr {$w-430}] 36 196 120 platform 1
            gstoreShot $c [expr {$w-250}] 78 210 140 chat 0
            gstoreIcon $c [expr {$w-470}] 150 52 draw
        }
        set y 274
        set y [gstoreShelf $c $y "Игры" games [gstoreTake games 6]]
        set y [gstoreShelf $c $y "Общение" talk [gstoreTake talk 5]]
        set y [gstoreShelf $c $y "Рисунок и звук" art [gstoreTake art 6]]
        set y [gstoreShelf $c $y "Интернет" net [gstoreTake net 6]]
        set y [gstoreShelf $c $y "На каждый день" apps [gstoreTake tool 6]]
        $c configure -scrollregion [list 0 0 $w $y]
        return
    }
    set head "Программы"
    set rows [gstoreByCat apps]
    if {$::gstorePage eq "games"} { set head "Игры"; set rows [gstoreByCat games] }
    if {$::gstorePage eq "talk"} { set head "Общение"; set rows [gstoreByCat talk] }
    if {$::gstorePage eq "art"} { set head "Творчество"; set rows [gstoreByCat art] }
    if {$::gstorePage eq "net"} { set head "Интернет"; set rows [gstoreByCat net] }
    $c create text 28 28 -anchor w -text $head -fill #f4f1ec -font storehero
    $c create text 28 64 -anchor w -text "Оценка стола и окно каждой программы." -fill #a3988c -font small
    set y [gstoreGrid $c 88 $rows]
    $c configure -scrollregion [list 0 0 $w $y]
}
proc openGStore {} {
    gstoreFonts
    set w [newWindow gstore "G-Store" 1180 780]
    set b $w.in.b
    if {![winfo exists $b.nav]} {
        $b configure -bg #161412
        frame $b.nav -bg #141210 -width 148
        pack $b.nav -side left -fill y
        pack propagate $b.nav 0
        label $b.nav.brand -text "G-Store" -bg #141210 -fg #e4c4a0 -font uib
        pack $b.nav.brand -anchor w -padx 18 -pady {20 4}
        label $b.nav.sub -text "Магазин стола" -bg #141210 -fg #a3988c -font tiny
        pack $b.nav.sub -anchor w -padx 18 -pady {0 16}
        foreach {id text} {home Главная games Игры talk Общение art Творчество apps Программы} {
            frame $b.nav.$id -bg #141210 -cursor hand2
            pack $b.nav.$id -fill x -pady 1
            frame $b.nav.$id.bar -bg #141210 -width 3
            pack $b.nav.$id.bar -side left -fill y
            pack propagate $b.nav.$id.bar 0
            label $b.nav.$id.t -text $text -bg #141210 -fg #f4f1ec -font ui -anchor w -padx 16 -pady 10
            pack $b.nav.$id.t -side left -fill x -expand 1
            bind $b.nav.$id <Button-1> [list gstorePage $id]
            bind $b.nav.$id.t <Button-1> [list gstorePage $id]
            bind $b.nav.$id.bar <Button-1> [list gstorePage $id]
        }
        frame $b.main -bg #161412
        pack $b.main -side left -fill both -expand 1
        frame $b.main.top -bg #161412
        pack $b.main.top -fill x -padx 20 -pady {14 0}
        frame $b.main.top.box -bg #221f1c -highlightthickness 1 -highlightbackground #3a332c
        pack $b.main.top.box -fill x -ipady 2
        label $b.main.top.box.ph -text "Поиск" -bg #221f1c -fg #8a8078 -font ui
        pack $b.main.top.box.ph -side left -padx {12 6} -pady 6
        entry $b.main.top.box.q -bg #221f1c -fg #f4f1ec -insertbackground #e4c4a0 -font ui \
            -bd 0 -highlightthickness 0 -relief flat
        pack $b.main.top.box.q -side left -fill x -expand 1 -padx {0 12} -pady 6
        bind $b.main.top.box.q <KeyRelease> gstoreSearchChanged
        canvas $b.main.c -bg #161412 -highlightthickness 0 -bd 0
        pack $b.main.c -fill both -expand 1 -pady 8
        bind $b.main.c <Configure> {
            if {![info exists ::gstoreW] || $::gstoreW != [winfo width %W]} {
                set ::gstoreW [winfo width %W]
                gstoreRender
            }
        }
        bind $b.main.c <Button-4> { %W yview scroll -4 units }
        bind $b.main.c <Button-5> { %W yview scroll 4 units }
        set ::gstorePage home
        set ::gstoreReady 0
        jobStart [list | /usr/bin/deepos-pkg installed] gstoreHave
    }
    gstoreMark
    gstoreRender
}
proc openPackages {} {
    set w [newWindow pkgs "Программы для администратора" 1080 680]
    set b $w.in.b
    if {![winfo exists $b.head]} {
        $b configure -bg #1c1c1c
        frame $b.head -bg #1c1c1c
        pack $b.head -fill x -padx 28 -pady {20 0}
        label $b.lead -text "Сырые пакеты: библиотеки, зависимости и служебные программы. Игры и обычные приложения — в G-Store." \
            -bg #1c1c1c -fg #8a8a8a -font small -anchor w
        pack $b.lead -fill x -padx 28 -pady {6 0}
        label $b.head.t -text "Программы для администратора" -bg #1c1c1c -fg #ffffff -font title -anchor w
        pack $b.head.t -side left
        label $b.head.idx -text "Обновить индекс" -bg #1c1c1c -fg #60cdff -font small -cursor hand2
        pack $b.head.idx -side right -pady 4
        bind $b.head.idx <Button-1> pkgIndex
        bind $b.head.idx <Enter> { .wpkgs.in.b.head.idx configure -fg #9cdcfe }
        bind $b.head.idx <Leave> { .wpkgs.in.b.head.idx configure -fg #60cdff }
        frame $b.search -bg #2d2d2d -height 48 \
            -highlightthickness 1 -highlightbackground #3f3f3f -highlightcolor #60cdff
        pack $b.search -side top -fill x -padx 28 -pady {16 8}
        pack propagate $b.search 0
        entry $b.q -bg #2d2d2d -fg #ffffff -insertbackground #ffffff -font ui \
            -bd 0 -highlightthickness 0 -relief flat
        pack $b.q -in $b.search -side left -fill both -expand 1 -padx {12 8}
        label $b.search.ph -text "Поиск программ" -bg #2d2d2d -fg #8a8a8a -font ui
        place $b.search.ph -in $b.search -x 14 -rely 0.5 -anchor w
        label $b.find -text "Найти" -bg #e4c4a0 -fg #1c1612 -font ui -padx 18 -pady 6 -cursor hand2
        pack $b.find -in $b.search -side right -padx {0 8} -pady 8
        bind $b.find <Button-1> pkgSearch
        bind $b.q <Return> pkgSearch
        bind $b.q <KeyRelease> pkgSearchHint
        bind $b.search.ph <Button-1> { focus .wpkgs.in.b.q }
        frame $b.cats -bg #1c1c1c
        pack $b.cats -side top -fill x -padx 28 -pady {0 4}
        foreach {id text query} {games Игры game office Офис libreoffice dev Разработка python3 draw Графика gimp net Сеть curl media Мультимедиа mpv} {
            label $b.cats.$id -text $text -bg #2d2d2d -fg #ffffff -font small -padx 10 -pady 6 -cursor hand2
            pack $b.cats.$id -side left -padx {0 6}
            bind $b.cats.$id <Button-1> [list pkgCat $query]
        }
        label $b.cats.hide -text "Скрыть установленные" -bg #2d2d2d -fg #ffffff -font small -padx 10 -pady 6 -cursor hand2
        pack $b.cats.hide -side right
        bind $b.cats.hide <Button-1> pkgToggleHide
        set ::pkgHide 0
        set ::pkgRaw {}
        label $b.st -text "Сначала обновите индекс, затем найдите пакет или откройте раздел." -bg #1c1c1c -fg #8a8a8a -font small -anchor w
        pack $b.st -side top -fill x -padx 28 -pady {2 0}
        frame $b.bar -bg #2a2a2a -height 10
        pack propagate $b.bar 0
        canvas $b.bar.c -bg #2a2a2a -height 10 -highlightthickness 0 -bd 0
        pack $b.bar.c -fill both -expand 1
        $b.bar.c create rectangle 0 0 0 10 -fill #60cdff -outline {} -tags fill
        set ::pkgFrac 0
        bind $b.bar.c <Configure> {
            if {[info exists ::pkgFrac]} {
                %W coords fill 0 0 [expr {int([winfo width %W] * $::pkgFrac)}] 10
            }
        }
        frame $b.side -bg #242424 -width 300
        pack $b.side -side right -fill y -padx {0 12} -pady {8 16}
        pack propagate $b.side 0
        label $b.side.t -text "Описание" -bg #242424 -fg #ffffff -font ui -anchor w
        pack $b.side.t -fill x -padx 12 -pady {12 4}
        label $b.side.n -text "Эскиз показывает схему окна. Это не фотография из репозитория. Оценок и отзывов нет." \
            -bg #242424 -fg #9a9a9a -font tiny -anchor w -wraplength 270 -justify left
        pack $b.side.n -fill x -padx 12
        canvas $b.side.pic -width 276 -height 132 -bg #141414 -highlightthickness 0
        pack $b.side.pic -padx 12 -pady {8 0}
        text $b.side.d -bg #242424 -fg #e8e8e8 -font small -wrap word -highlightthickness 0 -height 12
        pack $b.side.d -fill both -expand 1 -padx 12 -pady 8
        $b.side.d insert end "Здесь появятся описание и размер."
        $b.side.d configure -state disabled
        label $b.side.go -text "Установить" -bg #e4c4a0 -fg #1c1612 -font ui -padx 12 -pady 6 -cursor hand2
        pack $b.side.go -anchor w -padx 12 -pady {0 12}
        bind $b.side.go <Button-1> pkgInstallSel
        canvas $b.c -bg #1c1c1c -highlightthickness 0 -bd 0
        pack $b.c -side top -fill both -expand 1 -padx 12 -pady {8 16}
        bind $b.c <Configure> pkgReflow
        bind $b.c <Button-4> { %W yview scroll -4 units }
        bind $b.c <Button-5> { %W yview scroll 4 units }
        set ::pkgHits {}
        set ::pkgHave {}
        set ::pkgW 0
    }
    focus $b.q
    pkgInstalled
}
proc pkgSearchHint {} {
    set q [string trim [.wpkgs.in.b.q get]]
    if {![winfo exists .wpkgs.in.b.search.ph]} return
    if {$q eq ""} {
        place .wpkgs.in.b.search.ph -in .wpkgs.in.b.search -x 16 -rely 0.5 -anchor w
    } else {
        place forget .wpkgs.in.b.search.ph
    }
}
proc pkgLog {text} {
    set t .wpkgs.in.b.st
    if {![winfo exists $t]} return
    set line [string trim [lindex [split $text \n] 0]]
    if {[string length $line] > 90} { set line "[string range $line 0 88]..." }
    if {$line eq ""} return
    $t configure -text $line
}
proc pkgReflow {} {
    set c .wpkgs.in.b.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} return
    if {[info exists ::pkgW] && $::pkgW == $w} return
    set ::pkgW $w
    pkgRender
}
proc pkgShort {token} {
    if {[regexp {^(.*)-[0-9][^-]*-r[0-9]+$} $token -> name] && $name ne ""} { return $name }
    return $token
}
proc pkgRender {} {
    set c .wpkgs.in.b.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} {
        after 60 pkgRender
        return
    }
    $c delete all
    set y [pkgSection $c 8 "Результаты поиска" $::pkgHits install]
    set y [pkgSection $c [expr {$y + 18}] "Установленные" $::pkgHave remove]
    $c configure -scrollregion [list 0 0 $w [expr {$y + 16}]]
}
proc pkgSection {c y title items action} {
    set w [winfo width $c]
    $c create text 16 $y -anchor nw -text $title -fill #ffffff -font ui
    incr y 32
    if {[llength $items] == 0} {
        set empty "Ничего не найдено"
        if {$action eq "remove"} { set empty "Дополнительных программ пока нет" }
        if {$action eq "install"} {
            if {[info exists ::pkgSearched] && $::pkgSearched} {
                set empty "Ничего не найдено"
            } else {
                set empty "Здесь появятся пакеты после поиска"
            }
        }
        $c create text 16 $y -anchor nw -text $empty -fill #8a8a8a -font small
        return [expr {$y + 40}]
    }
    set i 0
    foreach name $items {
        set tag r$action$i
        set bg bg$tag
        $c create rectangle 8 $y [expr {$w - 8}] [expr {$y + 52}] -fill #2b2b2b -outline {} -tags [list $tag $bg]
        $c create text 24 [expr {$y + 26}] -anchor w -text $name -fill #f3f3f3 -font ui -tags $tag
        set label "Установить"
        set fill #e4c4a0
        set ink #1c1612
        set cmd [list pkgInstall $name]
        if {$action eq "remove"} {
            set label "Удалить"
            set fill #3a3a3a
            set ink #f3f3f3
            set cmd [list pkgRemove $name]
        }
        set x1 [expr {$w - 148}]
        set x2 [expr {$w - 20}]
        set btn b$tag
        $c create rectangle $x1 [expr {$y + 12}] $x2 [expr {$y + 40}] -fill $fill -outline {} -tags [list $btn]
        $c create text [expr {($x1 + $x2) / 2}] [expr {$y + 26}] -text $label -fill $ink -font small -tags [list $btn]
        $c bind $btn <Button-1> $cmd
        $c bind $tag <Button-1> [list pkgShow $name]
        $c bind $tag <Enter> [list $c itemconfigure $bg -fill #333333]
        $c bind $tag <Leave> [list $c itemconfigure $bg -fill #2b2b2b]
        incr y 60
        incr i
        if {$i >= 40} break
    }
    return $y
}
proc pkgIndex {} {
    notify "Пакеты" "Обновляю индекс пакетов..."
    jobStart [list | /usr/bin/deepos-pkg update] pkgIndexDone
}
proc pkgIndexDone {out} {
    if {[string match -nocase "*error*" $out] || [string match "*Unable to*" $out]} {
        pkgLog $out
        notify "Пакеты" "Не удалось обновить индекс"
        return
    }
    pkgLog "Индекс обновлён"
    notify "Пакеты" "Индекс обновлён"
}
proc pkgCat {q} {
    set e .wpkgs.in.b.q
    if {![winfo exists $e]} return
    $e delete 0 end
    $e insert 0 $q
    pkgSearchHint
    pkgSearch
}
proc pkgToggleHide {} {
    if {![info exists ::pkgHide]} { set ::pkgHide 0 }
    set ::pkgHide [expr {!$::pkgHide}]
    set lab .wpkgs.in.b.cats.hide
    if {[winfo exists $lab]} {
        if {$::pkgHide} {
            $lab configure -fg #e4c4a0
        } else {
            $lab configure -fg #ffffff
        }
    }
    pkgApplyFilter
}
proc pkgApplyFilter {} {
    if {![info exists ::pkgRaw]} { set ::pkgRaw {} }
    set hits {}
    foreach name $::pkgRaw {
        if {[info exists ::pkgHide] && $::pkgHide && [info exists ::pkgHave] && [lsearch -exact $::pkgHave $name] >= 0} continue
        lappend hits $name
    }
    set ::pkgHits $hits
    set ::pkgW 0
    pkgRender
}
proc pkgSearch {} {
    set q [string trim [.wpkgs.in.b.q get]]
    if {$q eq ""} return
    jobStart [list | /usr/bin/deepos-pkg search $q] pkgSearchDone
}
proc pkgScore {q name} {
    set ql [string tolower $q]
    set nl [string tolower $name]
    if {$nl eq $ql} { return 0 }
    if {$ql eq "python" && $nl eq "python3"} { return 0 }
    if {$nl eq "${ql}3"} { return 1 }
    if {[string first $ql $nl] == 0 && [string first - $nl] < 0} { return 2 }
    if {[string first $ql $nl] == 0} { return 3 }
    if {[string first $ql $nl] >= 0} { return 4 }
    return 5
}
proc pkgCmp {q a b} {
    set sa [pkgScore $q $a]
    set sb [pkgScore $q $b]
    if {$sa < $sb} { return -1 }
    if {$sa > $sb} { return 1 }
    return [string compare $a $b]
}
proc pkgSketch {name} {
    set c .wpkgs.in.b.side.pic
    if {![winfo exists $c]} return
    $c delete all
    $c create rectangle 0 0 276 132 -fill #141414 -outline {}
    set n [string tolower $name]
    set kind ""
    if {$n eq "python3" || [string match py3-* $n]} { set kind py }
    if {$n eq "firefox" || [string match chromium* $n] || $n eq "chrome"} { set kind web }
    if {$n eq "gimp" || $n eq "inkscape" || $n eq "blender"} { set kind draw }
    if {$n eq "vlc" || $n eq "mpv"} { set kind play }
    if {[string match libreoffice* $n]} { set kind doc }
    if {$n eq "vim" || $n eq "neovim" || $n eq "nano" || $n eq "git" || $n eq "htop"} { set kind term }
    if {$kind eq "py" || $kind eq "term"} {
        $c create rectangle 16 16 260 108 -fill #0c0c0c -outline #3a3a3a
        $c create rectangle 16 16 260 28 -fill #1c1c1c -outline {}
        if {$kind eq "py"} {
            $c create text 28 52 -anchor w -text ">>> " -fill #e4c4a0 -font small
            $c create text 58 52 -anchor w -text "print(2 + 2)" -fill #f3f3f3 -font small
            $c create text 28 74 -anchor w -text "4" -fill #9dcea6 -font small
        } else {
            $c create text 28 52 -anchor w -text "$ $n" -fill #9dcea6 -font small
            $c create text 28 74 -anchor w -text "готово" -fill #8a8a8a -font small
        }
    } elseif {$kind eq "web"} {
        $c create rectangle 16 16 260 108 -fill #f7f7f7 -outline {}
        $c create rectangle 16 16 260 36 -fill #e8e8e8 -outline {}
        $c create rectangle 36 22 180 32 -fill #ffffff -outline {}
        $c create text 138 70 -text $n -fill #5c564f -font small
    } elseif {$kind eq "draw"} {
        $c create rectangle 16 16 52 108 -fill #2a2a2a -outline {}
        $c create rectangle 58 16 200 108 -fill #d8d2c8 -outline {}
        $c create rectangle 206 16 260 108 -fill #2a2a2a -outline {}
        $c create oval 96 40 160 90 -outline #1c1612 -width 2
    } elseif {$kind eq "play"} {
        $c create rectangle 16 16 260 96 -fill #101010 -outline {}
        $c create polygon 124 40 124 76 156 58 -fill #e4c4a0 -outline {}
        $c create rectangle 16 96 260 108 -fill #2a2a2a -outline {}
    } elseif {$kind eq "doc"} {
        $c create rectangle 78 12 198 116 -fill #f4f1ec -outline #d0c8be
        $c create rectangle 92 32 184 38 -fill #1c1612 -outline {}
        $c create rectangle 92 48 184 52 -fill #c8c0b4 -outline {}
        $c create rectangle 92 58 170 62 -fill #c8c0b4 -outline {}
        $c create rectangle 92 68 176 72 -fill #c8c0b4 -outline {}
    } else {
        $c create rectangle 28 28 248 104 -fill #1c1c1c -outline #3a3a3a
        $c create text 138 52 -text $name -fill #f3f3f3 -font small
        $c create text 138 78 -text "Снимка в репозитории нет" -fill #8a8a8a -font tiny
        return
    }
    $c create text 16 122 -anchor w -text "Эскиз окна, не снимок из репозитория" -fill #6a6a6a -font tiny
}
proc pkgShow {name} {
    set ::pkgSel $name
    set t .wpkgs.in.b.side.d
    set h .wpkgs.in.b.side.t
    if {[winfo exists $h]} { $h configure -text $name }
    pkgSketch $name
    if {[winfo exists $t]} {
        $t configure -state normal
        $t delete 1.0 end
        $t insert end "Читаю описание..."
        $t configure -state disabled
    }
    jobStart [list | /bin/sh -c "/usr/bin/deepos-pkg info [pkgQuote $name] 2>&1"] [list pkgInfoDone $name]
}
proc pkgInfoDone {name out} {
    if {![info exists ::pkgSel] || $::pkgSel ne $name} return
    set t .wpkgs.in.b.side.d
    if {![winfo exists $t]} return
    set text [string trim $out]
    if {$text eq ""} { set text "Описание не найдено. Обновите индекс и повторите." }
    $t configure -state normal
    $t delete 1.0 end
    $t insert end $text
    $t configure -state disabled
}
proc pkgInstallSel {} {
    if {![info exists ::pkgSel] || $::pkgSel eq ""} return
    pkgInstall $::pkgSel
}
proc pkgNames {out} {
    set names {}
    foreach line [split $out \n] {
        set line [string trim $line]
        if {$line eq ""} continue
        if {[string match -nocase "fetch*" $line] || [string match -nocase "WARNING*" $line]} continue
        if {[string match -nocase "ERROR*" $line]} continue
        set name [pkgShort [lindex $line 0]]
        if {$name eq "" || [lsearch -exact $names $name] >= 0} continue
        lappend names $name
    }
    return $names
}
proc pkgSearchDone {out} {
    set ::pkgSearched 1
    set q ""
    if {[winfo exists .wpkgs.in.b.q]} { set q [string trim [.wpkgs.in.b.q get]] }
    set names [pkgNames $out]
    set ql [string tolower $q]
    if {$ql eq "python" || $ql eq "python3" || [string match *python* $ql]} {
        if {[lsearch -exact $names python3] < 0} { set names [linsert $names 0 python3] }
    }
    set ::pkgRaw [lsort -command [list pkgCmp $q] $names]
    pkgApplyFilter
    if {[llength $::pkgHits] == 0} {
        pkgLog "Ничего не найдено. Обновите индекс и повторите поиск."
    } else {
        pkgLog "Найдено: [llength $::pkgHits]"
    }
}
proc pkgInstalled {} {
    jobStart [list | /usr/bin/deepos-pkg installed] pkgInstalledDone
}
proc pkgInstalledDone {out} {
    set ::pkgHave [pkgNames $out]
    set ::pkgW 0
    pkgRender
}
proc pkgProgress {n m text} {
    set bar .wpkgs.in.b.bar
    set c $bar.c
    if {![winfo exists $c]} return
    if {![winfo ismapped $bar]} {
        pack $bar -side top -fill x -padx 28 -pady {8 0} -before .wpkgs.in.b.c
    }
    set w [winfo width $c]
    if {$w < 20} { set w 520 }
    set frac 0
    if {$m > 0} { set frac [expr {$n / double($m)}] }
    if {$frac < 0} { set frac 0 }
    if {$frac > 1} { set frac 1 }
    set ::pkgFrac $frac
    $c coords fill 0 0 [expr {int($w * $frac)}] 10
    set t .wpkgs.in.b.st
    if {[winfo exists $t]} { $t configure -text $text -fg #f3f3f3 }
}
proc pkgProgressHide {} {
    set bar .wpkgs.in.b.bar
    if {[winfo exists $bar]} { pack forget $bar }
}
proc pkgInstallLine {line} {
    set line [string trim $line]
    if {$line eq ""} return
    if {[regexp {\(([0-9]+)/([0-9]+)\)} $line -> n m]} {
        set verb "Установлено"
        if {[string match -nocase "*download*" $line] || [string match -nocase "*fetch*" $line]} {
            set verb "Загружено"
        }
        set rest $line
        regexp {\([0-9]+/[0-9]+\)\s*(.*)} $line -> rest
        pkgProgress $n $m "$verb $n из $m  ·  $rest"
        return
    }
    if {[string match -nocase "fetch*" $line] || [string match -nocase "*downloading*" $line]} {
        pkgLog "Загрузка: $line"
    }
}
proc pkgInstall {name} {
    if {![permAllows net]} {
        notify "Пакеты" "Установка запрещена: нет доступа к сети"
        journalAdd warn Разрешения "Установка $name запрещена"
        return
    }
    journalAdd info Пакеты "Установка: $name"
    notify "Пакеты" "Устанавливаю $name"
    pkgProgress 0 0 "Считаю зависимости для $name..."
    jobStart [list | /bin/sh -c "/usr/bin/deepos-pkg add [pkgQuote $name] 2>&1"] [list pkgAddDone $name] pkgInstallLine
}
proc pkgQuote {s} {
    return "'[string map {' '\\''} $s]'"
}
proc pkgPickBin {name} {
    set out [sh "apk info -L [pkgQuote $name] 2>/dev/null"]
    set bins {}
    set exact ""
    foreach line [split $out \n] {
        set line [string trim $line]
        if {![regexp {^(usr/bin|bin)/([^/]+)$} $line -> dir base]} continue
        set path /$line
        if {![file exists $path] || ![file executable $path]} continue
        if {$base eq $name} { set exact $path }
        lappend bins $path
    }
    if {$exact ne ""} { return $exact }
    if {[llength $bins] > 0} { return [lindex $bins 0] }
    return ""
}
proc pkgGui {bin} {
    set out [sh "ldd [pkgQuote $bin] 2>/dev/null"]
    if {[string match *libX11* $out] || [string match *libgtk* $out] || [string match *libQt* $out] || [string match *libSDL* $out]} {
        return 1
    }
    return 0
}
proc pkgShortcutPath {title} {
    regsub -all {[/\\:*?"<>|]} $title "" title
    set title [string trim $title]
    if {$title eq ""} { set title app }
    return [file join /root/Desktop "$title.deepos"]
}
proc pkgLine {path key} {
    foreach line [split [readFile $path 4000] \n] {
        if {$line eq $key} { return 1 }
    }
    return 0
}
proc pkgHasShortcut {name} {
    foreach f [glob -nocomplain -directory /root/Desktop *.deepos] {
        if {[pkgLine $f "pkg=$name"]} { return 1 }
    }
    return 0
}
proc pkgWriteShortcut {name} {
    if {[pkgHasShortcut $name]} { return "" }
    set bin [pkgPickBin $name]
    if {$bin eq ""} { return "" }
    file mkdir /root/Desktop
    set path [pkgShortcutPath [file tail $bin]]
    if {[file exists $path]} { set path [filesUnique $path] }
    set fh [open $path w]
    puts $fh "title=[file tail $bin]"
    puts $fh "bin=$bin"
    puts $fh "pkg=$name"
    puts $fh "gui=[pkgGui $bin]"
    close $fh
    return $path
}
proc pkgRemoveShortcut {name} {
    foreach f [glob -nocomplain -directory /root/Desktop *.deepos] {
        if {[pkgLine $f "pkg=$name"]} { catch { file delete $f } }
    }
}
proc pkgSyncShortcuts {} {
    set world /root/.deepos/world
    if {![file exists $world]} return
    set changed 0
    foreach name [split [readFile $world 20000] \n] {
        set name [string trim $name]
        if {$name eq ""} continue
        if {[pkgWriteShortcut $name] ne ""} { set changed 1 }
    }
    if {$changed} { paintDeskIcons }
}
proc launchShortcut {path} {
    set title ""
    set bin ""
    set gui 0
    foreach line [split [readFile $path 2000] \n] {
        if {[regexp {^title=(.*)$} $line -> title]} continue
        if {[regexp {^bin=(.*)$} $line -> bin]} continue
        if {[regexp {^gui=([01])$} $line -> gui]} continue
    }
    if {$bin eq "" || ![file executable $bin]} {
        notify "Ярлык" "Программа не найдена"
        return
    }
    if {$title eq ""} { set title [file tail $bin] }
    if {$gui} {
        set base [file tail $bin]
        if {$base eq "firefox"} { openApp firefox; return }
        if {$base eq "chromium-browser" || $base eq "chromium"} { openApp chrome; return }
        openGuest $title $bin
        return
    }
    termExec $bin
}
proc termExec {cmd} {
    openTerm
    set t .wterm.in.b.t
    if {![winfo exists $t]} return
    if {[catch {$t index termIn}]} { termPrompt }
    set cur [string trim [$t get termIn end-1c]]
    if {$cur ne ""} {
        $t insert end \n out
        termPrompt
    }
    $t insert end $cmd
    termRun
}
proc pkgAddDone {name out} {
    pkgInstalled
    if {[string match -nocase "*error*" $out] || [string match "*ERROR*" $out] || [string match "*failed*" $out]} {
        pkgLog $out
        after 1600 pkgProgressHide
        journalAdd error Пакеты "Не установлено: $name"
        notify "Пакеты" "Не удалось установить $name"
        return
    }
    journalAdd info Пакеты "Установлено: $name"
    set m 0
    foreach line [split $out \n] {
        if {[regexp {\(([0-9]+)/([0-9]+)\)} $line -> a b]} { set m $b }
    }
    if {$m > 0} {
        pkgProgress $m $m "Установлено $m из $m"
    } else {
        pkgProgress 1 1 "Установлено: $name"
    }
    after 1600 pkgProgressHide
    updNote "установка" $name
    set link [pkgWriteShortcut $name]
    paintDeskIcons
    if {$link eq ""} {
        notify "Пакеты" "Установлено: $name"
    } else {
        notify "Пакеты" "Установлено: $name. Ярлык на рабочем столе."
    }
}
proc pkgRemove {name} {
    notify "Пакеты" "Удаляю $name"
    pkgLog "Удаляю $name..."
    jobStart [list | /usr/bin/deepos-pkg del $name] [list pkgDelDone $name]
}
proc pkgDelDone {name out} {
    pkgLog $out
    pkgInstalled
    pkgRemoveShortcut $name
    paintDeskIcons
    updNote "удаление" $name
    journalAdd info Пакеты "Удалено: $name"
    notify "Пакеты" "Удалено: $name"
}
proc openMonitor {} {
    set w [newWindow monitor "Диспетчер задач" 1080 700]
    set b $w.in.b
    if {![winfo exists $b.nav]} {
        $b configure -bg #1c1c1c
        if {![info exists ::monPage]} { set ::monPage procs }
        set ::monSel ""
        set ::monRows {}
        set ::monCpuHist {}
        set ::monMemHist {}
        set ::monSysCpu 0
        set ::monMemUsed 0
        set ::monMemTotal 1
        set ::monOpen(app) 1
        set ::monOpen(bg) 1
        set ::monOpen(sys) 1
        frame $b.nav -bg #191919 -width 220
        pack $b.nav -side left -fill y
        pack propagate $b.nav 0
        frame $b.nav.pad -bg #191919 -height 14
        pack $b.nav.pad -fill x
        foreach {id label} {procs "Процессы" perf "Производительность" boot "Автозагрузка" details "Подробности"} {
            monNav $id $label
        }
        frame $b.sep -bg #2a2a2a -width 1
        pack $b.sep -side left -fill y
        frame $b.main -bg #1c1c1c
        pack $b.main -side left -fill both -expand 1
        monShow $::monPage
    }
    if {[info exists ::monTick]} { after cancel $::monTick }
    monRefresh
    set ::monTick [after 1000 monTick]
}
proc monNav {id label} {
    set f .wmonitor.in.b.nav.$id
    frame $f -bg #191919 -height 42 -cursor hand2
    pack $f -fill x -padx 8 -pady 2
    pack propagate $f 0
    frame $f.mark -bg #191919 -width 3
    pack $f.mark -side left -fill y -padx {0 8}
    label $f.t -text $label -bg #191919 -fg #f3f3f3 -font ui -anchor w -cursor hand2
    pack $f.t -side left -fill both -expand 1
    foreach w [list $f $f.t $f.mark] {
        bind $w <Button-1> [list monShow $id]
    }
}
proc monMark {} {
    foreach id {procs perf boot details} {
        set f .wmonitor.in.b.nav.$id
        if {![winfo exists $f]} continue
        if {$id eq $::monPage} {
            $f configure -bg #2d2d2d
            $f.t configure -bg #2d2d2d
            $f.mark configure -bg #60cdff
        } else {
            $f configure -bg #191919
            $f.t configure -bg #191919
            $f.mark configure -bg #191919
        }
    }
}
proc monShow {page} {
    set ::monPage $page
    monMark
    set m .wmonitor.in.b.main
    foreach c [winfo children $m] { destroy $c }
    if {$page eq "perf"} {
        monBuildPerf
    } elseif {$page eq "boot"} {
        monBuildBoot
    } else {
        monBuildTable
    }
    monRefresh
}
proc monBuildTable {} {
    set m .wmonitor.in.b.main
    frame $m.bar -bg #1c1c1c -height 56
    pack $m.bar -side top -fill x
    pack propagate $m.bar 0
    frame $m.bar.q -bg #2d2d2d -highlightthickness 1 -highlightbackground #3a3a3a
    pack $m.bar.q -side left -fill both -expand 1 -padx {16 8} -pady 10
    entry $m.bar.q.e -bg #2d2d2d -fg #ffffff -insertbackground #ffffff -font ui \
        -bd 0 -highlightthickness 0 -relief flat
    pack $m.bar.q.e -side left -fill both -expand 1 -padx 12
    label $m.bar.q.ph -text "Поиск по имени или PID" -bg #2d2d2d -fg #8a8a8a -font ui
    place $m.bar.q.ph -in $m.bar.q -x 14 -rely 0.5 -anchor w
    bind $m.bar.q.e <KeyRelease> monQuery
    bind $m.bar.q.ph <Button-1> { focus .wmonitor.in.b.main.bar.q.e }
    label $m.bar.end -text "Завершить задачу" -bg #2d2d2d -fg #6a6a6a -font ui \
        -padx 14 -pady 8 -cursor hand2
    pack $m.bar.end -side right -padx {0 16} -pady 10
    bind $m.bar.end <Button-1> monKill
    canvas $m.h -bg #1c1c1c -height 32 -highlightthickness 0
    pack $m.h -side top -fill x -padx 8
    canvas $m.c -bg #1c1c1c -highlightthickness 0
    pack $m.c -side top -fill both -expand 1 -padx 8 -pady {0 10}
    bind $m.c <Configure> { set ::monDrawW 0; monDraw }
    bind $m.h <Configure> monHead
    bind $m.c <Button-4> { %W yview scroll -3 units }
    bind $m.c <Button-5> { %W yview scroll 3 units }
}
proc monQuery {} {
    set e .wmonitor.in.b.main.bar.q.e
    set ph .wmonitor.in.b.main.bar.q.ph
    if {[winfo exists $e] && [winfo exists $ph]} {
        if {[string trim [$e get]] eq ""} {
            place $ph -in .wmonitor.in.b.main.bar.q -x 14 -rely 0.5 -anchor w
        } else {
            place forget $ph
        }
    }
    monDraw
}
proc monBuildPerf {} {
    set m .wmonitor.in.b.main
    label $m.title -text "Производительность" -bg #1c1c1c -fg #ffffff -font title -anchor w
    pack $m.title -side top -fill x -padx 24 -pady {18 8}
    frame $m.cpu -bg #2b2b2b
    pack $m.cpu -side top -fill x -padx 24 -pady 8
    label $m.cpu.k -text "ЦП" -bg #2b2b2b -fg #8a8a8a -font small -anchor w
    label $m.cpu.v -text "0%" -bg #2b2b2b -fg #ffffff -font title -anchor w
    pack $m.cpu.k -anchor w -padx 16 -pady {12 0}
    pack $m.cpu.v -anchor w -padx 16
    canvas $m.cpu.g -bg #2b2b2b -height 78 -highlightthickness 0
    pack $m.cpu.g -fill x -padx 16 -pady {4 12}
    frame $m.mem -bg #2b2b2b
    pack $m.mem -side top -fill x -padx 24 -pady 8
    label $m.mem.k -text "Память" -bg #2b2b2b -fg #8a8a8a -font small -anchor w
    label $m.mem.v -text "0 МБ" -bg #2b2b2b -fg #ffffff -font title -anchor w
    pack $m.mem.k -anchor w -padx 16 -pady {12 0}
    pack $m.mem.v -anchor w -padx 16
    canvas $m.mem.g -bg #2b2b2b -height 78 -highlightthickness 0
    pack $m.mem.g -fill x -padx 16 -pady {4 12}
}
proc monTick {} {
    if {![winfo exists .wmonitor.in.b.nav]} return
    monRefresh
    set ::monTick [after 1000 monTick]
}
proc monState {s} {
    switch -glob -- $s {
        R { return "Выполняется" }
        Z { return "Завершён" }
        T { return "Остановлен" }
        default { return "Ожидание" }
    }
}
proc monMemText {kb} {
    if {$kb >= 1048576} { return [format "%.1f ГБ" [expr {$kb / 1048576.0}]] }
    if {$kb >= 1024} { return [format "%.0f МБ" [expr {$kb / 1024.0}]] }
    return "$kb КБ"
}
proc monKind {pid name ppid tty} {
    if {$pid <= 2 || $ppid == 2} { return sys }
    if {[string match {\[*} $name]} { return sys }
    switch -- $name {
        init - linuxrc - Xorg - X - xinit -
        dbus-daemon - dbus-launch - NetworkManager -
        udevd - systemd-udevd - syslogd - klogd { return sys }
    }
    if {$pid == [pid] || $name eq "wish" || $name eq "netsurf" || $name eq "mc" || $name eq "nano"} {
        return app
    }
    if {$tty != 0} { return app }
    return bg
}
proc monTitle {name} {
    switch -- $name {
        wish { return "DeepOS" }
        netsurf { return "Sun Browser" }
        default { return $name }
    }
}
proc monSelKind {} {
    if {![info exists ::monSel] || $::monSel eq ""} { return "" }
    foreach row $::monRows {
        if {[lindex $row 0] eq $::monSel} { return [lindex $row 6] }
    }
    return ""
}
proc monToggle {kind} {
    if {![info exists ::monOpen($kind)]} { set ::monOpen($kind) 1 }
    set ::monOpen($kind) [expr {!$::monOpen($kind)}]
    monDraw
}
proc monSample {} {
    set stat [readFile /proc/stat 240]
    set line [lindex [split $stat \n] 0]
    set total 0
    set idle 0
    if {[regexp {^cpu\s+(.*)} $line -> rest]} {
        set nums {}
        foreach n [lrange $rest 0 7] {
            if {![string is integer -strict $n]} continue
            lappend nums $n
            incr total $n
        }
        if {[llength $nums] > 3} { set idle [lindex $nums 3] }
    }
    if {![info exists ::monPrevTotal]} {
        set ::monPrevTotal $total
        set ::monPrevIdle $idle
    }
    set dTot [expr {$total - $::monPrevTotal}]
    set dIdle [expr {$idle - $::monPrevIdle}]
    set ::monPrevTotal $total
    set ::monPrevIdle $idle
    set ::monSysCpu 0
    if {$dTot > 0} {
        set ::monSysCpu [expr {100.0 * ($dTot - $dIdle) / double($dTot)}]
        if {$::monSysCpu < 0} { set ::monSysCpu 0 }
        if {$::monSysCpu > 100} { set ::monSysCpu 100 }
    }
    set rows {}
    foreach dir [glob -nocomplain -directory /proc -type d {[0-9]*}] {
        set pid [file tail $dir]
        if {![string is integer -strict $pid]} continue
        set raw [readFile [file join $dir stat] 500]
        set lp [string first ( $raw]
        set rp [string last ) $raw]
        if {$lp < 0 || $rp <= $lp} continue
        set name [string range $raw [expr {$lp + 1}] [expr {$rp - 1}]]
        set rest [string trim [string range $raw [expr {$rp + 1}] end]]
        set f [split $rest]
        if {[llength $f] < 13} continue
        set utime [lindex $f 11]
        set stime [lindex $f 12]
        if {![string is integer -strict $utime] || ![string is integer -strict $stime]} continue
        set ticks [expr {$utime + $stime}]
        set prev 0
        if {[info exists ::monPrev($pid)]} { set prev $::monPrev($pid) }
        set ::monPrev($pid) $ticks
        set cpu 0.0
        if {$dTot > 0} {
            set cpu [expr {100.0 * ($ticks - $prev) / double($dTot)}]
            if {$cpu < 0} { set cpu 0 }
            if {$cpu > 100} { set cpu 100 }
        }
        set rss 0
        set user root
        set ppid 0
        set tty 0
        if {[string is integer -strict [lindex $f 1]]} { set ppid [lindex $f 1] }
        if {[string is integer -strict [lindex $f 4]]} { set tty [lindex $f 4] }
        set status [readFile [file join $dir status] 1500]
        regexp {VmRSS:\s+(\d+)} $status -> rss
        if {[regexp {Uid:\s+(\d+)} $status -> uid] && $uid != 0} { set user $uid }
        set kind [monKind $pid $name $ppid $tty]
        lappend rows [list $pid [monTitle $name] [lindex $f 0] $cpu $rss $user $kind $name]
    }
    if {[array exists ::monPrev]} {
        foreach pid [array names ::monPrev] {
            if {![file exists /proc/$pid]} { unset ::monPrev($pid) }
        }
    }
    set ::monRows [lsort -real -decreasing -index 3 $rows]
    lappend ::monCpuHist $::monSysCpu
    if {[llength $::monCpuHist] > 48} { set ::monCpuHist [lrange $::monCpuHist end-47 end] }
    set info [readFile /proc/meminfo 500]
    set mt 1
    set ma 0
    regexp {MemTotal:\s+(\d+)} $info -> mt
    regexp {MemAvailable:\s+(\d+)} $info -> ma
    set ::monMemTotal $mt
    set ::monMemUsed [expr {$mt - $ma}]
    if {$::monMemUsed < 0} { set ::monMemUsed 0 }
    set mp 0
    if {$mt > 0} { set mp [expr {100.0 * $::monMemUsed / double($mt)}] }
    lappend ::monMemHist $mp
    if {[llength $::monMemHist] > 48} { set ::monMemHist [lrange $::monMemHist end-47 end] }
}
proc monFilter {} {
    set q ""
    set e .wmonitor.in.b.main.bar.q.e
    if {[winfo exists $e]} { set q [string tolower [string trim [$e get]]] }
    set view {}
    foreach row $::monRows {
        if {$q eq ""} {
            lappend view $row
            continue
        }
        set name [string tolower "[lindex $row 1] [lindex $row 7]"]
        if {[string match *$q* $name] || [string match *$q* [lindex $row 0]]} {
            lappend view $row
        }
    }
    return $view
}
proc monHead {} {
    set c .wmonitor.in.b.main.h
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} return
    $c delete all
    if {$::monPage eq "details"} {
        set cols {{0.02 w PID} {0.12 w Имя} {0.34 w Пользователь} {0.52 w Состояние} {0.74 e ЦП} {0.96 e Память}}
    } else {
        set cols {{0.02 w Имя} {0.50 w Состояние} {0.74 e ЦП} {0.96 e Память}}
    }
    foreach col $cols {
        lassign $col rel anchor text
        $c create text [expr {int($w * $rel)}] 16 -anchor $anchor -text $text -fill #8a8a8a -font small
    }
    $c create line 8 31 [expr {$w - 8}] 31 -fill #2a2a2a
}
proc monDraw {} {
    set c .wmonitor.in.b.main.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} return
    monHead
    set q ""
    set e .wmonitor.in.b.main.bar.q.e
    if {[winfo exists $e]} { set q [string trim [$e get]] }
    set ::monView [monFilter]
    array set bucket {app {} bg {} sys {}}
    foreach row $::monView {
        set k bg
        if {[llength $row] > 6 && [lindex $row 6] ne ""} { set k [lindex $row 6] }
        if {![info exists bucket($k)]} { set k bg }
        lappend bucket($k) $row
    }
    $c delete all
    set y 4
    set i 0
    foreach {k title} {app Приложения bg {Фоновые процессы} sys Системные} {
        set rows $bucket($k)
        set n [llength $rows]
        if {$n == 0 && $q ne ""} continue
        set open 1
        if {$q eq "" && [info exists ::monOpen($k)]} { set open $::monOpen($k) }
        set mark "▾"
        if {!$open} { set mark "▸" }
        set htag h$k
        $c create rectangle 0 $y $w [expr {$y + 34}] -fill #252525 -outline {} -tags [list $htag hbg$k]
        $c create text 16 [expr {$y + 17}] -anchor w -text "$mark    $title ($n)" -fill #ffffff -font ui -tags $htag
        $c bind $htag <Button-1> [list monToggle $k]
        incr y 40
        if {!$open} continue
        foreach row $rows {
            lassign $row pid name state cpu rss user
            set bg #1c1c1c
            if {$pid eq $::monSel} { set bg #333333 }
            set tag r$i
            $c create rectangle 0 $y $w [expr {$y + 42}] -fill $bg -outline {} -tags [list $tag bg$i]
            set cpuText [format "%.1f%%" $cpu]
            set memText [monMemText $rss]
            set stateText [monState $state]
            if {$::monPage eq "details"} {
                $c create text [expr {int($w * 0.02)}] [expr {$y + 21}] -anchor w -text $pid -fill #f3f3f3 -font small -tags $tag
                $c create text [expr {int($w * 0.12)}] [expr {$y + 21}] -anchor w -text $name -fill #f3f3f3 -font small -tags $tag
                $c create text [expr {int($w * 0.34)}] [expr {$y + 21}] -anchor w -text $user -fill #d0d0d0 -font small -tags $tag
                $c create text [expr {int($w * 0.52)}] [expr {$y + 21}] -anchor w -text $stateText -fill #d0d0d0 -font small -tags $tag
                $c create text [expr {int($w * 0.74)}] [expr {$y + 21}] -anchor e -text $cpuText -fill #f3f3f3 -font small -tags $tag
                $c create text [expr {int($w * 0.96)}] [expr {$y + 21}] -anchor e -text $memText -fill #f3f3f3 -font small -tags $tag
            } else {
                $c create text 28 [expr {$y + 21}] -anchor w -text $name -fill #f3f3f3 -font ui -tags $tag
                $c create text [expr {int($w * 0.50)}] [expr {$y + 21}] -anchor w -text $stateText -fill #d0d0d0 -font small -tags $tag
                $c create text [expr {int($w * 0.74)}] [expr {$y + 21}] -anchor e -text $cpuText -fill #f3f3f3 -font small -tags $tag
                $c create text [expr {$w - 16}] [expr {$y + 21}] -anchor e -text $memText -fill #f3f3f3 -font small -tags $tag
            }
            $c bind $tag <Button-1> [list monPick $pid]
            if {$pid ne $::monSel} {
                $c bind $tag <Enter> [list $c itemconfigure bg$i -fill #262626]
                $c bind $tag <Leave> [list $c itemconfigure bg$i -fill #1c1c1c]
            }
            incr y 46
            incr i
        }
    }
    if {$i == 0 && $q ne ""} {
        $c create text 16 $y -anchor w -text "Ничего не найдено" -fill #8a8a8a -font small
        incr y 28
    }
    $c configure -scrollregion [list 0 0 $w $y]
    monEndStyle
}
proc monPick {pid} {
    set ::monSel $pid
    monDraw
}
proc monEndStyle {} {
    set b .wmonitor.in.b.main.bar.end
    if {![winfo exists $b]} return
    set kind [monSelKind]
    if {$::monSel eq "" || $kind eq "sys" || ($::monSel ne "" && ($::monSel <= 1 || $::monSel == [pid]))} {
        $b configure -fg #6a6a6a
    } else {
        $b configure -fg #ffffff
    }
}
proc monBars {c values color} {
    if {![winfo exists $c]} return
    $c delete all
    set w [winfo width $c]
    set h [winfo height $c]
    if {$w < 20} { set w 400 }
    if {$h < 10} { set h 70 }
    set n 48
    set bw [expr {double($w) / $n}]
    set i 0
    set start [expr {$n - [llength $values]}]
    foreach v $values {
        if {$v < 0} { set v 0 }
        if {$v > 100} { set v 100 }
        set bh [expr {$v / 100.0 * ($h - 6)}]
        if {$bh < 1 && $v > 0} { set bh 1 }
        set x [expr {($start + $i) * $bw}]
        $c create rectangle $x [expr {$h - $bh}] [expr {$x + $bw - 1}] [expr {$h - 1}] -fill $color -outline {}
        incr i
    }
}
proc monRefresh {} {
    if {![winfo exists .wmonitor.in.b.nav]} return
    monSample
    if {$::monPage eq "boot"} { return }
    if {$::monPage eq "perf"} {
        if {[winfo exists .wmonitor.in.b.main.cpu.v]} {
            .wmonitor.in.b.main.cpu.v configure -text [format "%.0f%%" $::monSysCpu]
            monBars .wmonitor.in.b.main.cpu.g $::monCpuHist #60cdff
        }
        if {[winfo exists .wmonitor.in.b.main.mem.v]} {
            set used [monMemText $::monMemUsed]
            set total [monMemText $::monMemTotal]
            .wmonitor.in.b.main.mem.v configure -text "$used  /  $total"
            monBars .wmonitor.in.b.main.mem.g $::monMemHist #e4c4a0
        }
        return
    }
    monDraw
}
proc monKill {} {
    if {![info exists ::monSel] || $::monSel eq ""} return
    if {![string is integer -strict $::monSel]} return
    if {[monSelKind] eq "sys"} {
        notify "Диспетчер задач" "Системный процесс нельзя завершить"
        return
    }
    if {$::monSel <= 1 || $::monSel == [pid]} {
        notify "Диспетчер задач" "Этот процесс нельзя завершить"
        return
    }
    set name $::monSel
    foreach row $::monRows {
        if {[lindex $row 0] eq $::monSel} { set name [lindex $row 1] }
    }
    catch { exec kill $::monSel }
    notify "Диспетчер задач" "Завершена задача $name"
    set ::monSel ""
    after 200 monRefresh
}
proc takeShot {} {
    file mkdir /root/Desktop
    set name [clock format [clock seconds] -format "Снимок-%Y%m%d-%H%M%S.png"]
    set path [file join /root/Desktop $name]
    if {[catch {exec scrot $path} err]} {
        notify "Снимок экрана" "Не удалось сохранить"
        return
    }
    notify "Снимок экрана" $name
    paintDeskIcons
}
proc openUpdates {} {
    set w [newWindow updates "Обновления" 700 480]
    set b $w.in.b
    if {![winfo exists $b.log]} {
        $b configure -bg #141210
        set pretty "DeepOS"
        foreach line [split [readFile /etc/os-release 800] \n] {
            if {[string match PRETTY_NAME=* $line]} {
                set pretty [string trim [string range $line 12 end] \"]
            }
        }
        label $b.ver -text $pretty -bg #141210 -fg #f6f1ea -font title -anchor w
        pack $b.ver -fill x -padx 18 -pady {14 6}
        frame $b.act -bg #141210
        pack $b.act -fill x -padx 18
        button $b.act.check -text "Проверить" -command updatesCheck -bg #241f1b -fg #f6f1ea -font ui -padx 12 -pady 6
        button $b.act.go -text "Установить" -command updatesGo -bg #e4c4a0 -fg #1c1612 -font ui -padx 12 -pady 6
        pack $b.act.check $b.act.go -side left -padx 4
        text $b.log -bg #100e0c -fg #cccccc -font small -highlightthickness 0 -wrap word
        pack $b.log -fill both -expand 1 -padx 18 -pady 12
    }
}
proc updatesLog {text} {
    set t .wupdates.in.b.log
    if {![winfo exists $t]} return
    $t insert end $text\n
    $t see end
}
proc updatesCheck {} {
    notify "Обновления" "Проверяю пакеты..."
    jobStart [list | /bin/sh -c "/usr/bin/deepos-pkg update && /usr/bin/deepos-pkg plan"] updatesChecked
}
proc updatesChecked {out} {
    updatesLog $out
    set n [updatesCount $out]
    if {[string match -nocase "*error*" $out] || [string match "*Unable to*" $out]} {
        set ::updStatus "Проверка не удалась"
        notify "Обновления" "Не удалось проверить пакеты"
    } elseif {$n > 0} {
        set ::updStatus "Можно обновить пакетов: $n"
        notify "Обновления" "Можно обновить пакетов: $n"
    } else {
        set ::updStatus "Новых пакетов нет"
        notify "Обновления" "Новых пакетов нет"
    }
    updNote "проверка" $::updStatus
}
proc updatesGo {} {
    notify "Обновления" "Устанавливаю обновления пакетов..."
    jobStart [list | /usr/bin/deepos-pkg upgrade] updatesDone
}
proc updatesDone {out} {
    updatesLog $out
    set n [updatesCount $out]
    updNote "установка пакетов" "обновлено строк: $n"
    notify "Обновления" "Готово. Образ DeepOS обновляется сборкой на компьютере."
}
proc updatesAuto {} {
    if {[info exists ::bootUpdates] && !$::bootUpdates} { return }
    if {![permAllows net]} {
        journalAdd warn Разрешения "Проверка обновлений пропущена: нет доступа к сети"
        return
    }
    set addr ""
    catch { set addr [sh "ip -4 -o addr show scope global 2>/dev/null"] }
    if {![string match *inet* $addr]} {
        after 600000 updatesAuto
        return
    }
    jobStart [list | /bin/sh -c "/usr/bin/deepos-pkg update && /usr/bin/deepos-pkg plan"] updatesAutoDone
}
proc updatesAutoDone {out} {
    if {![string match -nocase "*error*" $out] && ![string match "*Unable to*" $out]} {
        set n [updatesCount $out]
        if {$n > 0} {
            set key "pkg:$n"
            if {![info exists ::updSeen] || $::updSeen ne $key} {
                set ::updSeen $key
                set ::updStatus "Можно обновить пакетов: $n"
                notify "Обновления" "Доступно пакетов: $n"
                if {[info exists ::setPage] && $::setPage eq "updates" && [winfo exists .wsettings.in.b.page]} {
                    settingsShow updates
                }
            }
        }
    }
    after 1800000 updatesAuto
}
proc openByType {path} {
    set ext [string tolower [file extension $path]]
    switch -- $ext {
        .txt - .text - .md - .sh - .conf - .cfg - .ini - .log - .json - .tcl - .me - .csv {
            openEditor $path
        }
        .png - .gif {
            openImage $path
        }
        .jpg - .jpeg {
            notify "Файл" "JPEG хранится как файл. Просмотр открывает PNG и GIF."
        }
        .deepos {
            launchShortcut $path
        }
        .exe {
            openExe $path
        }
        default {
            openViewer $path
        }
    }
}
proc openEditor {path} {
    set id ed[clock milliseconds]
    set ::pinicon($id) doc
    set ::editPath($id) $path
    set w [newWindow $id [file tail $path] 720 520]
    set b $w.in.b
    $b configure -bg #141210
    frame $b.bar -bg #141210
    pack $b.bar -fill x -padx 12 -pady 8
    button $b.bar.save -text "Сохранить" -command [list editorSave $id] -bg #e4c4a0 -fg #1c1612 -font ui -padx 12
    pack $b.bar.save -side left
    text $b.t -bg #100e0c -fg #f6f1ea -insertbackground #e4c4a0 -font mono \
        -highlightthickness 0 -undo 1 -padx 12 -pady 12
    pack $b.t -fill both -expand 1 -padx 12 -pady {0 12}
    $b.t insert end [readFile $path 200000]
}
proc editorSave {id} {
    set path $::editPath($id)
    set data [.w$id.in.b.t get 1.0 end-1c]
    if {[catch {
        set fh [open $path w]
        puts -nonewline $fh $data
        close $fh
    } err]} {
        notify "Редактор" "Не удалось сохранить"
        return
    }
    notify "Редактор" "Сохранено: [file tail $path]"
}
proc openImage {path} {
    set id im[clock milliseconds]
    set ::pinicon($id) doc
    set w [newWindow $id [file tail $path] 760 540]
    if {[catch {image create photo $id -file $path} err]} {
        label $w.in.b.err -text "Не удалось открыть изображение" -bg $::MICA -fg $::WHITE -font ui
        pack $w.in.b.err -padx 20 -pady 20
        return
    }
    canvas $w.in.b.c -bg #111111 -highlightthickness 0
    pack $w.in.b.c -fill both -expand 1
    $w.in.b.c create image 12 12 -anchor nw -image $id
}

proc dialog {title} {
    if {[winfo exists .ask]} { destroy .ask }
    toplevel .ask
    wm overrideredirect .ask 1
    wm geometry .ask 420x180+[expr {($::SW-420)/2}]+[expr {($::SH-180)/2}]
    .ask configure -bg $::ACCENT
    frame .ask.in -bg $::MICA
    pack .ask.in -fill both -expand 1 -padx {4 0} -pady 0
    label .ask.in.t -text $title -bg $::MICA -fg $::WHITE -font title -anchor w -cursor fleur
    pack .ask.in.t -anchor w -padx 22 -pady {18 10}
    bind .ask.in.t <ButtonPress-1> [list beginDrag .ask %X %Y]
}

proc createEntry {kind} {
    hideCtx
    set prompt [expr {$kind eq "dir" ? "Имя папки" : "Имя файла"}]
    dialog $prompt
    entry .ask.in.e -bg $::CARD -fg $::WHITE -insertbackground $::ACCENT -font ui \
        -highlightthickness 1 -highlightbackground $::LINE -highlightcolor $::ACCENT
    pack .ask.in.e -fill x -padx 22 -ipady 6
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 16
    button .ask.in.bt.ok -text "Создать" -command [list doCreate $kind] -bg $::ACCENT -fg $::INK -font ui -padx 12 -pady 6
    button .ask.in.bt.no -text "Отмена" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
    pack .ask.in.bt.no .ask.in.bt.ok -side right -padx 10
    focus .ask.in.e
    bind .ask.in.e <Return> [list doCreate $kind]
}
proc doCreate {kind} {
    set name [string trim [.ask.in.e get]]
    destroy .ask
    if {$name eq "" || [string match */* $name] || $name eq "." || $name eq ".."} return
    file mkdir /root/Desktop
    set path [file join /root/Desktop $name]
    if {[file exists $path]} return
    if {$kind eq "dir"} { file mkdir $path } else { close [open $path w] }
    refreshIcons
    paintDeskIcons
    if {[winfo exists .wfiles] && [info exists ::filesPath] && $::filesPath eq "/root/Desktop"} { openFiles $::filesPath }
}

proc shutdown {} {
    dialog "Выключить DeepOS?"
    frame .ask.in.bt -bg $::MICA
    pack .ask.in.bt -fill x -pady 8
    button .ask.in.bt.ok -text "Выключить" -command doShutdown -bg $::DANGER -fg $::WHITE \
        -activebackground #a34436 -font ui -padx 12 -pady 6
    button .ask.in.bt.no -text "Отмена" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
    pack .ask.in.bt.no .ask.in.bt.ok -side right -padx 16
}
proc doShutdown {} {
    catch {exec poweroff -f}
    catch {exec reboot -f}
    exit
}
proc doReboot {} {
    hideStart
    catch {exec reboot -f}
    exit
}
proc doSleep {} {
    hideStart
    if {[catch {exec /bin/sh -c "echo mem > /sys/power/state"} err]} {
        dialog "Спящий режим недоступен"
        frame .ask.in.bt -bg $::MICA
        pack .ask.in.bt -fill x -pady 8
        button .ask.in.bt.no -text "Закрыть" -command {destroy .ask} -bg $::CARD -fg $::WHITE -font ui -padx 12 -pady 6
        pack .ask.in.bt.no -side right -padx 16
    }
}
proc accountColors {} {
    return {#e4c4a0 #d4655d #a3b18a #7eb6ff #c9a6e0 #e0b15a}
}
proc accountInitial {name} {
    set ch [string index [string trim $name] 0]
    if {$ch eq ""} { return "?" }
    return $ch
}
proc accountDraw {c size avatar name} {
    $c delete all
    set colors [accountColors]
    set n [llength $colors]
    if {![string is integer -strict $avatar]} { set avatar 0 }
    set avatar [expr {$avatar % $n}]
    set fill [lindex $colors $avatar]
    $c create oval 2 2 [expr {$size - 2}] [expr {$size - 2}] -fill $fill -outline {}
    $c create text [expr {$size / 2}] [expr {$size / 2}] -text [accountInitial $name] -fill #1c1612 -font taskb
}
proc accountIds {} {
    set ids {}
    if {![file isdirectory /persist/accounts]} { return {} }
    foreach d [glob -nocomplain -directory /persist/accounts u*] {
        set id [file tail $d]
        if {![regexp {^u[0-9]+$} $id]} continue
        if {![file exists [file join $d meta]]} continue
        lappend ids $id
    }
    return [lsort $ids]
}
proc accountMeta {id} {
    set name ""
    set salt ""
    set hash ""
    set avatar 0
    set path /persist/accounts/$id/meta
    if {[file exists $path]} {
        set fh [open $path r]
        while {[gets $fh line] >= 0} {
            if {[regexp {^name=(.*)$} $line -> v]} { set name $v }
            if {[regexp {^salt=(.*)$} $line -> v]} { set salt $v }
            if {[regexp {^hash=(.*)$} $line -> v]} { set hash $v }
            if {[regexp {^avatar=([0-9]+)$} $line -> v]} { set avatar $v }
        }
        close $fh
    }
    return [list name $name salt $salt hash $hash avatar $avatar]
}
proc accountWriteMeta {id name salt hash avatar} {
    file mkdir /persist/accounts/$id
    set fh [open /persist/accounts/$id/meta w]
    puts $fh "name=$name"
    puts $fh "salt=$salt"
    puts $fh "hash=$hash"
    puts $fh "avatar=$avatar"
    close $fh
}
proc accountSalt {} {
    set a [expr {abs([clock clicks])}]
    set b [clock milliseconds]
    return [format "%x%x" $a $b]
}
proc accountHash {salt secret} {
    set path /tmp/deepos-auth-[clock milliseconds]
    set fh [open $path w]
    fconfigure $fh -translation binary
    puts -nonewline $fh $salt
    puts -nonewline $fh ":"
    puts -nonewline $fh $secret
    close $fh
    if {[catch {exec sha256sum $path} out]} {
        catch {file delete -force $path}
        return ""
    }
    catch {file delete -force $path}
    return [lindex $out 0]
}
proc accountCheck {id secret} {
    array set m [accountMeta $id]
    if {$m(hash) eq "" || $m(salt) eq ""} { return 0 }
    set got [accountHash $m(salt) $secret]
    if {$got eq "" || $got ne $m(hash)} { return 0 }
    return 1
}
proc accountPrepareHome {id} {
    set home /persist/accounts/$id/home
    file mkdir $home
    if {[file exists $home/.seeded]} { return }
    set others 0
    foreach item [accountIds] {
        if {$item ne $id} { incr others }
    }
    if {$others == 0 && [file isdirectory /persist/home/.deepos]} {
        catch {exec cp -a /persist/home/. $home/}
    }
    file mkdir $home/.deepos
    file mkdir $home/Desktop
    file mkdir $home/.Trash
    close [open $home/.seeded w]
}
proc accountMount {id} {
    if {![regexp {^u[0-9]+$} $id]} { return 0 }
    set home /persist/accounts/$id/home
    file mkdir $home/.deepos
    if {![file exists $home/.deepos/settings] && [file exists /etc/deepos/settings]} {
        file copy -force /etc/deepos/settings $home/.deepos/settings
    }
    set cur ""
    if {[file exists /persist/accounts/mounted]} {
        set cur [string trim [readFile /persist/accounts/mounted 80]]
    }
    if {$cur ne $id} {
        if {$cur ne ""} {
            catch {exec /bin/sh -c "cd / && umount /root"}
        }
        if {[catch {exec mount --bind $home /root} err]} { return 0 }
        set fh [open /persist/accounts/mounted w]
        puts $fh $id
        close $fh
    }
    catch {exec /bin/sh -c "echo DEEPOS_LOGIN $id > /dev/ttyS0"}
    return 1
}
proc accountUnmount {} {
    catch {exec /bin/sh -c "cd / && sync"}
    set cur ""
    if {[file exists /persist/accounts/mounted]} {
        set cur [string trim [readFile /persist/accounts/mounted 80]]
    }
    if {$cur eq ""} { return 1 }
    # Free anything still holding the home bind, then force the mount off.
    catch {exec /bin/sh -c {fuser -km /root >/dev/null 2>&1 || true}}
    catch {exec sleep 0.2}
    if {[catch {exec /bin/sh -c "cd / && umount /root"}]} {
        catch {exec /bin/sh -c "cd / && umount -l /root"}
    }
    if {[catch {exec /bin/sh -c "mountpoint -q /root"}]} {
        catch {file delete -force /persist/accounts/mounted}
        return 1
    }
    # Still mounted: last resort lazy unmount.
    if {[catch {exec /bin/sh -c "cd / && umount -l /root"}]} { return 0 }
    catch {file delete -force /persist/accounts/mounted}
    return 1
}
proc accountPaintWho {} {
    set name $::user
    if {$name eq ""} { set name "Гость" }
    set avatar 0
    if {[info exists ::accountAvatar]} { set avatar $::accountAvatar }
    if {[winfo exists .desk.menu.foot.row.av]} {
        accountDraw .desk.menu.foot.row.av 32 $avatar $name
    }
    if {[winfo exists .desk.menu.foot.row.u]} {
        .desk.menu.foot.row.u configure -text $name
    }
    if {[winfo exists .wsettings.in.b.nav.who.av]} {
        accountDraw .wsettings.in.b.nav.who.av 36 $avatar $name
    }
    if {[winfo exists .wsettings.in.b.nav.who.n]} {
        .wsettings.in.b.nav.who.n configure -text $name
    }
    if {[winfo exists .wsettings.in.b.nav.who.m]} {
        .wsettings.in.b.nav.who.m configure -text "Свои файлы и настройки"
    }
}
proc accountEnter {id} {
    if {![accountMount $id]} { return 0 }
    array set m [accountMeta $id]
    set ::accountId $id
    set ::user $m(name)
    set ::accountAvatar $m(avatar)
    settingsLoad
    themeApply
    fontApply
    cursorApply
    recentLoad
    browserLinks
    pkgSyncShortcuts
    paintDeskIcons
    paintPins
    accountPaintWho
    permLoad
    if {[info exists ::gateTick]} { after cancel $::gateTick }
    catch {grab release .gate}
    catch {destroy .gate}
    journalAdd info Вход "Вход: $m(name)"
    bootRun
    focus -force .desk
    return 1
}
proc accountCloseApps {} {
    foreach id [lrange $::wins 0 end] {
        catch {closeWin $id}
    }
    catch {sunStopAll}
    catch {hostStop firefox}
    catch {hostStop chrome}
    catch {exec sh -c {for p in $(pidof firefox firefox-bin chromium chromium-browser chrome netsurf netsurf-gtk nsgtk wine wine64 2>/dev/null); do kill -TERM $p 2>/dev/null; done; sleep 0.2; for p in $(pidof firefox firefox-bin chromium chromium-browser chrome netsurf netsurf-gtk nsgtk wine wine64 2>/dev/null); do kill -KILL $p 2>/dev/null; done}}
}
proc accountSecretField {box label name cmd} {
    label $box.l$name -text $label -bg #1a1714 -fg #a3988c -font small -anchor w
    pack $box.l$name -fill x -pady {8 4}
    frame $box.f$name -bg #3a342c
    pack $box.f$name -fill x
    entry $box.$name -show * -bg #241f1b -fg #f6f1ea -insertbackground #e4c4a0 -font ui \
        -relief flat -bd 0 -highlightthickness 0
    pack $box.$name -in $box.f$name -fill x -padx 1 -pady 1 -ipady 8 -ipadx 10
    bind $box.$name <Return> $cmd
}
proc journalAdd {level source text} {
    if {![file isdirectory /persist]} { return }
    set path /persist/journal
    set lines {}
    if {[file exists $path]} {
        set fh [open $path r]
        set lines [split [read $fh] \n]
        close $fh
    }
    lappend lines "[clock seconds]\t$level\t$source\t$text"
    set keep {}
    foreach line $lines {
        if {$line ne ""} { lappend keep $line }
    }
    if {[llength $keep] > 400} { set keep [lrange $keep end-399 end] }
    set fh [open $path w]
    puts $fh [join $keep \n]
    close $fh
    catch { logReload }
}
proc permDefaults {} {
    return {files 1 mic 0 camera 0 net 1 geo 1 notify 1}
}
proc permLoad {} {
    array set ::perm [permDefaults]
    set path /root/.deepos/grants
    if {![file exists $path]} { return }
    set fh [open $path r]
    while {[gets $fh line] >= 0} {
        if {![regexp {^([a-z]+)\s+([01])$} $line -> key on]} continue
        if {[info exists ::perm($key)]} { set ::perm($key) $on }
    }
    close $fh
}
proc permAllows {key} {
    if {![info exists ::perm($key)]} { permLoad }
    if {![info exists ::perm($key)]} { return 1 }
    return $::perm($key)
}
proc permSave {} {
    file mkdir /root/.deepos
    set fh [open /root/.deepos/grants w]
    foreach {key on} [array get ::perm] {
        puts $fh "$key $on"
    }
    close $fh
}
proc permTitle {key} {
    switch -- $key {
        files { return "Файлы" }
        mic { return "Микрофон" }
        camera { return "Камера" }
        net { return "Сеть" }
        geo { return "Геолокация" }
        notify { return "Уведомления" }
        default { return $key }
    }
}
proc guestDenied {title bin} {
    set base [file tail $bin]
    set why {}
    if {[lsearch -exact {audacity obs obs-studio} $base] >= 0 && ![permAllows mic]} {
        lappend why "микрофон"
    }
    if {[lsearch -exact {obs obs-studio} $base] >= 0 && ![permAllows camera]} {
        lappend why "камера"
    }
    if {[lsearch -exact {firefox chromium chromium-browser thunderbird telegram-desktop transmission-gtk filezilla dino nheko pidgin vlc kodi} $base] >= 0 && ![permAllows net]} {
        lappend why "сеть"
    }
    if {[llength $why] == 0} { return 0 }
    set text "Нет разрешения: [join $why {, }]"
    notify $title $text
    journalAdd warn Разрешения "$title: $text"
    return 1
}
proc bootRows {} {
    return {
        app term Терминал
        app files Файлы
        app browse {Sun Browser}
        app firefox Firefox
        app chrome Chrome
        app chat DeepChat
        app gstore G-Store
        app calendar Календарь
        app monitor {Диспетчер задач}
        app log {Системный журнал}
        svc weather Погода
        svc updates {Проверка обновлений}
    }
}
proc bootDefault {id} {
    if {$id eq "weather" || $id eq "updates"} { return 1 }
    return 0
}
proc bootMap {} {
    array set m {}
    foreach {kind id title} [bootRows] {
        set m($id) [bootDefault $id]
    }
    set path /root/.deepos/autostart
    if {[file exists $path]} {
        set fh [open $path r]
        while {[gets $fh line] >= 0} {
            if {![regexp {^(\S+)\s+([01])$} $line -> id on]} continue
            if {[info exists m($id)]} { set m($id) $on }
        }
        close $fh
    }
    return [array get m]
}
proc bootOn {id} {
    array set m [bootMap]
    if {![info exists m($id)]} { return 0 }
    return $m($id)
}
proc bootTitle {id} {
    foreach {kind item title} [bootRows] {
        if {$item eq $id} { return $title }
    }
    return $id
}
proc bootSave {id on} {
    array set m [bootMap]
    if {![info exists m($id)]} { return }
    set m($id) $on
    file mkdir /root/.deepos
    set fh [open /root/.deepos/autostart w]
    foreach {kind item title} [bootRows] {
        puts $fh "$item $m($item)"
    }
    close $fh
    set word "выключено"
    if {$on} { set word "включено" }
    journalAdd info Автозагрузка "[bootTitle $id]: $word"
}
proc bootRun {} {
    set ::bootWeather [bootOn weather]
    set ::bootUpdates [bootOn updates]
    if {$::bootUpdates} {
        set ::updAuto [after 20000 updatesAuto]
    }
    set delay 500
    foreach {kind id title} [bootRows] {
        if {$kind ne "app"} continue
        if {![bootOn $id]} continue
        after $delay [list openApp $id]
        journalAdd info Автозагрузка "Запуск: $title"
        incr delay 450
    }
    if {!$::bootWeather} {
        weatherShow "Автозагрузка погоды выключена"
    }
}
proc logFilter {id} {
    set ::logFilter $id
    logReload
}
proc logReload {} {
    set t .wlog.in.b.list
    if {![winfo exists $t]} return
    foreach id {all error warn info} {
        set w .wlog.in.b.bar.f$id
        if {![winfo exists $w]} continue
        if {$id eq $::logFilter} {
            $w configure -bg #e4c4a0 -fg #1c1612
        } else {
            $w configure -bg #2a241e -fg #f6f1ea
        }
    }
    $t configure -state normal
    $t delete 1.0 end
    set raw ""
    if {[file exists /persist/journal]} { set raw [readFile /persist/journal 300000] }
    set shown 0
    foreach line [split $raw \n] {
        if {![regexp {^([0-9]+)\t(info|warn|error)\t([^\t]*)\t(.*)$} $line -> when level source text]} continue
        if {$::logFilter ne "all" && $::logFilter ne $level} continue
        set stamp [clock format $when -format "%d.%m %H:%M"]
        $t insert end "$stamp  " time
        set mark "событие"
        if {$level eq "warn"} { set mark "предупреждение" }
        if {$level eq "error"} { set mark "ошибка" }
        $t insert end "$mark  " $level
        $t insert end "$source — $text\n"
        incr shown
    }
    if {$shown == 0} {
        $t insert end "Пока пусто. Здесь появятся входы, установки, разрешения и автозагрузка."
    }
    $t configure -state disabled
    $t see end
}
proc openLog {} {
    set w [newWindow log "Системный журнал" 960 640]
    set b $w.in.b
    if {![info exists ::logFilter]} { set ::logFilter all }
    if {[winfo exists $b.list]} { logReload; return }
    $b configure -bg #141210
    frame $b.bar -bg #141210
    pack $b.bar -fill x -padx 18 -pady {14 8}
    label $b.bar.t -text "Системный журнал" -bg #141210 -fg #f6f1ea -font title
    pack $b.bar.t -side left -padx {0 16}
    foreach {id text} {all Все error Ошибки warn Предупреждения info События} {
        label $b.bar.f$id -text $text -bg #2a241e -fg #f6f1ea -font small -padx 12 -pady 6 -cursor hand2
        pack $b.bar.f$id -side left -padx 4
        bind $b.bar.f$id <Button-1> [list logFilter $id]
    }
    text $b.list -bg #1a1714 -fg #f6f1ea -font small -relief flat -highlightthickness 0 \
        -wrap word -state disabled -cursor left_ptr -padx 12 -pady 10
    pack $b.list -fill both -expand 1 -padx 18 -pady {0 16}
    $b.list tag configure error -foreground #e81123
    $b.list tag configure warn -foreground #e0b15a
    $b.list tag configure info -foreground #a3b18a
    $b.list tag configure time -foreground #6e675f
    logReload
}
proc permFlip {key} {
    permLoad
    set ::perm($key) [expr {!$::perm($key)}]
    permSave
    set word "запрещено"
    if {$::perm($key)} { set word "разрешено" }
    journalAdd info Разрешения "[permTitle $key]: $word"
    if {[info exists ::setPage] && $::setPage eq "perm"} { settingsShow perm }
}
proc settingsPerm {} {
    permLoad
    set p [settingsHead "РАЗРЕШЕНИЯ"]
    label $p.note -text "Правила этой учётки. Запрет сети останавливает браузеры, установку, погоду и проверку обновлений. Запрет файлов прячет документы от чужих программ." \
        -bg #1f1f1f -fg #9a9a9a -font small -anchor w -wraplength 640 -justify left
    pack $p.note -fill x -padx 28 -pady {0 12}
    foreach {key title hint} {
        files "Файлы" "Чужие программы видят документы этой учётки."
        mic "Микрофон" "Запись звука, например в Audacity."
        camera "Камера" "Камера в программах вроде OBS."
        net "Сеть" "Браузеры, установка программ, погода и обновления."
        geo "Геолокация" "Погода узнаёт место по сети."
        notify "Уведомления" "Всплывающие сообщения на столе."
    } {
        frame $p.r$key -bg #2d2d2d
        pack $p.r$key -fill x -padx 28 -pady 4
        label $p.r$key.t -text $title -bg #2d2d2d -fg #ffffff -font ui -anchor w
        label $p.r$key.h -text $hint -bg #2d2d2d -fg #9a9a9a -font small -anchor w
        set on [permAllows $key]
        set word "Выкл"
        set bg #3a3a3a
        set fg #ffffff
        if {$on} { set word "Вкл"; set bg #e4c4a0; set fg #1c1612 }
        label $p.r$key.b -text $word -bg $bg -fg $fg -font ui -padx 16 -pady 8 -cursor hand2
        pack $p.r$key.b -side right -padx 12 -pady 10
        pack $p.r$key.t -anchor w -padx 16 -pady {10 0}
        pack $p.r$key.h -anchor w -padx 16 -pady {0 10}
        bind $p.r$key.b <Button-1> [list permFlip $key]
    }
}
proc monBuildBoot {} {
    set m .wmonitor.in.b.main
    label $m.title -text "Автозагрузка" -bg #1c1c1c -fg #ffffff -font title -anchor w
    pack $m.title -fill x -padx 24 -pady {18 4}
    label $m.note -text "Эти программы и службы запускаются вместе со входом в учётку." \
        -bg #1c1c1c -fg #8a8a8a -font small -anchor w
    pack $m.note -fill x -padx 24 -pady {0 10}
    canvas $m.c -bg #1c1c1c -highlightthickness 0
    pack $m.c -fill both -expand 1 -padx 16 -pady {0 12}
    bind $m.c <Configure> monBootPaint
    monBootPaint
}
proc monBootPaint {} {
    set c .wmonitor.in.b.main.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    if {$w < 80} { set w 640 }
    $c delete all
    set y 8
    set i 0
    foreach {kind id title} [bootRows] {
        set on [bootOn $id]
        set bg #252525
        $c create rectangle 8 $y [expr {$w - 8}] [expr {$y + 52}] -fill $bg -outline {}
        set cap "Программа"
        if {$kind eq "svc"} { set cap "Служба" }
        $c create text 24 [expr {$y + 18}] -anchor w -text $title -fill #f6f1ea -font ui
        $c create text 24 [expr {$y + 36}] -anchor w -text $cap -fill #8a8a8a -font tiny
        set word "Выкл"
        set fill #3a3a3a
        set ink #f6f1ea
        if {$on} { set word "Вкл"; set fill #e4c4a0; set ink #1c1612 }
        set tag t$i
        $c create rectangle [expr {$w - 108}] [expr {$y + 12}] [expr {$w - 24}] [expr {$y + 40}] -fill $fill -outline {} -tags $tag
        $c create text [expr {$w - 66}] [expr {$y + 26}] -text $word -fill $ink -font ui -tags $tag
        $c bind $tag <Button-1> [list bootToggle $id]
        incr y 60
        incr i
    }
    $c configure -scrollregion [list 0 0 $w $y]
}
proc bootToggle {id} {
    set on [expr {![bootOn $id]}]
    bootSave $id $on
    if {$id eq "weather"} { set ::bootWeather $on }
    if {$id eq "updates"} { set ::bootUpdates $on }
    monBootPaint
}
proc accountGateTick {} {
    if {![winfo exists .gate.c]} return
    gatePaintChrome
    set ::gateTick [after 1000 accountGateTick]
}
proc gatePaintBg {} {
    set c .gate.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    set h [winfo height $c]
    if {$w < 100 || $h < 100} {
        set w $::SW
        set h $::SH
    }
    $c delete glow
    lockGlow $c [expr {$w * 0.82}] [expr {$h * 0.08}] [expr {$w * 0.46}] #c4a27a 0.30
    lockGlow $c [expr {$w * 0.08}] [expr {$h * 0.92}] [expr {$w * 0.38}] #8a5a28 0.24
    lockGlow $c [expr {$w * 0.50}] [expr {$h * 0.46}] [expr {$w * 0.28}] #e4c4a0 0.07
}
proc gatePaintChrome {} {
    set c .gate.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    set h [winfo height $c]
    if {$w < 100 || $h < 100} {
        set w $::SW
        set h $::SH
    }
    $c delete chrome
    set now [clock seconds]
    set hhmm [clock format $now -format [timeFmt]]
    set sec [clock format $now -format "%S"]
    set day [string trim [clock format $now -format "%e"]]
    set months {января февраля марта апреля мая июня июля августа сентября октября ноября декабря}
    set days {воскресенье понедельник вторник среда четверг пятница суббота}
    set mon [lindex $months [expr {[clock format $now -format "%m"] - 1}]]
    set wday [lindex $days [clock format $now -format "%w"]]
    set year [clock format $now -format "%Y"]
    $c create rectangle 32 22 42 32 -fill #e4c4a0 -outline {} -tags chrome
    $c create text 52 27 -anchor w -text "DeepOS" -fill #e4c4a0 -font lockbrand -tags chrome
    $c create text [expr {$w - 32}] 27 -anchor e -text "[lockPretty]   ·   Вход" -fill #8d8680 -font locktiny -tags chrome
    set yb [expr {$h - 150}]
    if {$h < 700} { set yb [expr {$h - 120}] }
    $c create text 64 $yb -anchor sw -text $hhmm -fill #f4f1ec -font locktime -tags chrome
    set tw [font measure locktime $hhmm]
    set th [font metrics locktime -linespace]
    $c create text [expr {64 + $tw + 16}] [expr {$yb - $th + [font metrics locksec -ascent] + 8}] \
        -anchor nw -text $sec -fill #e4c4a0 -font locksec -tags chrome
    $c create text 64 [expr {$yb + 18}] -anchor nw -text "$day $mon $year, $wday" -fill #b9b2aa -font ui -tags chrome
    set wx [lockWeatherText]
    if {$wx ne ""} {
        $c create text 64 [expr {$yb + 46}] -anchor nw -text $wx -fill #e4c4a0 -font small -tags chrome
    }
    $c create text 32 [expr {$h - 28}] -anchor w -text "DeepOS" -fill #7a746e -font locktiny -tags chrome
    $c create text [expr {$w - 32}] [expr {$h - 28}] -anchor e -text "Enter  —  войти" -fill #7a746e -font locktiny -tags chrome
}
proc gateLayout {} {
    if {![winfo exists .gate]} return
    lockFonts
    wm geometry .gate ${::SW}x${::SH}+0+0
    if {[winfo exists .gate.c]} {
        .gate.c configure -width $::SW -height $::SH
        place .gate.c -x 0 -y 0 -width $::SW -height $::SH
    }
    gatePaintBg
    gatePaintChrome
    if {![winfo exists .gate.shell]} return
    set cw 360
    if {[winfo exists .gate.shell.card.pad.box.name]} { set cw 420 }
    if {$::SW >= 1000} {
        place .gate.shell -x [expr {$::SW - 56}] -rely 0.46 -anchor e -width $cw
    } else {
        place .gate.shell -relx 0.5 -rely 0.58 -anchor center -width $cw
    }
    raise .gate.shell
}
proc gateShake {n} {
    if {![winfo exists .gate.shell]} return
    set dx [lindex {0 -10 10 -7 7 -3 0} $n]
    if {$dx eq ""} { set dx 0 }
    set cw 360
    if {[winfo exists .gate.shell.card.pad.box.name]} { set cw 420 }
    if {$::SW >= 1000} {
        place .gate.shell -x [expr {$::SW - 56 + $dx}] -rely 0.46 -anchor e -width $cw
    } else {
        place .gate.shell -relx 0.5 -x $dx -rely 0.58 -anchor center -width $cw
    }
    if {$n < 6} { after 36 [list gateShake [expr {$n + 1}]] }
}
proc gateDrawUser {{hot 0}} {
    set c .gate.shell.card.pad.box.av
    if {![winfo exists $c]} return
    $c delete all
    set avatar 0
    set name ""
    if {[info exists ::accountPick] && $::accountPick ne ""} {
        array set m [accountMeta $::accountPick]
        set avatar $m(avatar)
        set name $m(name)
        unset m
    }
    set colors [accountColors]
    if {![string is integer -strict $avatar]} { set avatar 0 }
    set fill [lindex $colors [expr {$avatar % [llength $colors]}]]
    if {$hot} {
        $c create oval 2 2 106 106 -outline #e4c4a0 -width 2
    } else {
        $c create oval 6 6 102 102 -outline #5a4632 -width 1
    }
    $c create oval 14 14 94 94 -fill $fill -outline {}
    $c create text 54 54 -text [accountInitial $name] -fill #141414 -font lockav
}
proc gateReveal {} {
    set pin .gate.shell.card.pad.box.pin
    if {![winfo exists $pin]} return
    set ::gatePin 1
    pack $pin -fill x -pady {18 0} -before .gate.shell.card.pad.box.err
    if {[winfo exists .gate.shell.card.pad.box.hint]} {
        .gate.shell.card.pad.box.hint configure -text ""
    }
    focus .gate.shell.card.pad.box.sec
}
proc gateReturn {} {
    if {[winfo exists .gate.shell.card.pad.box.name]} return
    accountLogin
}
proc accountPickAvatar {a} {
    set ::accountNewAvatar $a
    for {set i 0} {$i < 6} {incr i} {
        set c .gate.shell.card.pad.box.avs.a$i
        if {![winfo exists $c]} continue
        accountDraw $c 48 $i "А"
        if {$i == $a} {
            $c create oval 1 1 46 46 -outline #e4c4a0 -width 2
        }
    }
}
proc accountSelect {id} {
    set ::accountPick $id
    if {[winfo exists .gate.shell.card.pad.box.who]} {
        array set m [accountMeta $id]
        .gate.shell.card.pad.box.who configure -text $m(name)
        unset m
    }
    gateDrawUser
    set i 0
    foreach item [accountIds] {
        set c .gate.shell.card.pad.box.alts.a$i
        if {[winfo exists $c]} {
            array set m [accountMeta $item]
            accountDraw $c 36 $m(avatar) $m(name)
            if {$item eq $id} { $c create oval 1 1 34 34 -outline #e4c4a0 -width 2 }
            unset m
        }
        incr i
    }
    if {[info exists ::gatePin] && $::gatePin && [winfo exists .gate.shell.card.pad.box.sec]} {
        .gate.shell.card.pad.box.sec delete 0 end
        focus .gate.shell.card.pad.box.sec
    }
}
proc accountField {box name} {
    frame $box.f$name -bg #3a342c
    pack $box.f$name -fill x -pady {0 10}
    entry $box.$name -bg #241f1b -fg #f6f1ea -insertbackground #e4c4a0 -font ui \
        -relief flat -bd 0 -highlightthickness 0
    pack $box.$name -in $box.f$name -fill x -padx 1 -pady 1 -ipady 8 -ipadx 12
}
proc accountGo {box text cmd} {
    label $box.go -text $text -bg #e4c4a0 -fg #1c1612 -font uib -padx 16 -pady 12 -cursor hand2
    pack $box.go -fill x -pady {8 4}
    bind $box.go <Button-1> $cmd
    bind $box.go <Enter> [list $box.go configure -bg #f0d2b4]
    bind $box.go <Leave> [list $box.go configure -bg #e4c4a0]
}
proc accountForm {mode} {
    if {![winfo exists .gate.shell.card.pad]} return
    if {[winfo exists .gate.shell.card.pad.box]} { destroy .gate.shell.card.pad.box }
    if {[winfo exists .gate.shell.card.pad.h]} { destroy .gate.shell.card.pad.h }
    set box .gate.shell.card.pad.box
    frame $box -bg #1a1714
    pack $box -fill both -expand 1
    if {$mode eq "pick"} {
        set ::gatePin 0
        set ::accountPick ""
        canvas $box.av -width 108 -height 108 -bg #1a1714 -highlightthickness 0 -cursor hand2
        pack $box.av -pady {8 0}
        label $box.who -text "" -bg #1a1714 -fg #f4f1ec -font lockname
        pack $box.who -pady {10 2}
        label $box.hint -text "НАЖМИТЕ НА АВАТАР, ЧТОБЫ ВОЙТИ" -bg #1a1714 -fg #8d8680 -font locktiny
        pack $box.hint
        set ids [accountIds]
        if {[llength $ids] > 1} {
            frame $box.alts -bg #1a1714
            pack $box.alts -pady {10 0}
            set i 0
            foreach id $ids {
                canvas $box.alts.a$i -width 36 -height 36 -bg #1a1714 -highlightthickness 0 -cursor hand2
                pack $box.alts.a$i -side left -padx 4
                bind $box.alts.a$i <Button-1> [list accountSelect $id]
                if {$::accountPick eq ""} { set ::accountPick $id }
                incr i
            }
        } elseif {[llength $ids] == 1} {
            set ::accountPick [lindex $ids 0]
        }
        frame $box.pin -bg #1a1714
        frame $box.pin.row -bg #2a241e
        pack $box.pin.row -fill x
        entry $box.sec -show * -bg #14120f -fg #f4f1ec -insertbackground #e4c4a0 \
            -font ui -relief flat -bd 0 -highlightthickness 0
        pack $box.sec -in $box.pin.row -side left -fill x -expand 1 -padx 1 -pady 1 -ipady 8 -ipadx 12
        label $box.go -text "Войти" -bg #e4c4a0 -fg #141414 -font uib -padx 14 -pady 8 -cursor hand2
        pack $box.go -in $box.pin.row -side right -padx 4 -pady 4
        label $box.err -text "" -bg #1a1714 -fg #e07b7b -font small -wraplength 280 -justify left
        pack $box.err -fill x -pady {8 0}
        label $box.new -text "Новый пользователь" -bg #1a1714 -fg #e4c4a0 -font task -cursor hand2
        pack $box.new -pady {12 8}
        bind $box.av <Button-1> gateReveal
        bind $box.av <Enter> { gateDrawUser 1 }
        bind $box.av <Leave> { gateDrawUser 0 }
        bind $box.go <Button-1> accountLogin
        bind $box.go <Enter> [list $box.go configure -bg #f0d2b4]
        bind $box.go <Leave> [list $box.go configure -bg #e4c4a0]
        bind $box.sec <Return> { accountLogin; break }
        bind $box.new <Button-1> { accountForm create }
        if {$::accountPick ne ""} { accountSelect $::accountPick }
    } else {
        label .gate.shell.card.pad.h -text "Новый пользователь" -bg #1a1714 -fg #f6f1ea -font title -anchor w
        pack .gate.shell.card.pad.h -before $box -anchor w -pady {0 10}
        label $box.ln -text "Имя" -bg #1a1714 -fg #a3988c -font small -anchor w
        pack $box.ln -fill x -pady {0 4}
        accountField $box name
        bind $box.name <Return> [list focus $box.sec]
        label $box.la -text "Аватар" -bg #1a1714 -fg #a3988c -font small -anchor w
        pack $box.la -fill x -pady {2 6}
        frame $box.avs -bg #1a1714
        pack $box.avs -anchor w -pady {0 4}
        set ::accountNewAvatar 0
        for {set a 0} {$a < 6} {incr a} {
            canvas $box.avs.a$a -width 48 -height 48 -bg #1a1714 -highlightthickness 0 -cursor hand2
            pack $box.avs.a$a -side left -padx {0 8}
            bind $box.avs.a$a <Button-1> [list accountPickAvatar $a]
        }
        accountPickAvatar 0
        accountSecretField $box "Пароль или PIN" sec accountCreate
        accountSecretField $box "Ещё раз" sec2 accountCreate
        label $box.err -text "" -bg #1a1714 -fg #e07b7b -font small -wraplength 340 -justify left -anchor w
        pack $box.err -fill x
        accountGo $box "Создать и войти" accountCreate
        if {[llength [accountIds]] > 0} {
            label $box.back -text "Назад к входу" -bg #1a1714 -fg #e4c4a0 -font task -cursor hand2 -anchor w
            pack $box.back -fill x -pady {4 0}
            bind $box.back <Button-1> { accountForm pick }
        }
        focus $box.name
    }
    gateLayout
}
proc accountGate {} {
    if {![file isdirectory /persist]} { return }
    file mkdir /persist/accounts
    catch {file delete -force /persist/accounts/active}
    if {[info exists ::gateTick]} { after cancel $::gateTick }
    if {[winfo exists .gate]} { destroy .gate }
    lockFonts
    toplevel .gate
    wm overrideredirect .gate 1
    wm geometry .gate ${::SW}x${::SH}+0+0
    .gate configure -bg #0f0f0f
    canvas .gate.c -bg #0f0f0f -highlightthickness 0 -bd 0
    place .gate.c -x 0 -y 0 -width $::SW -height $::SH
    frame .gate.shell -bg #3a342c
    frame .gate.shell.card -bg #1a1714
    pack .gate.shell.card -fill both -expand 1 -padx 1 -pady 1
    frame .gate.shell.card.pad -bg #1a1714
    pack .gate.shell.card.pad -fill both -expand 1 -padx 28 -pady 28
    bind .gate <Return> gateReturn
    bind .gate <Escape> break
    if {[llength [accountIds]] == 0} {
        accountForm create
    } else {
        accountForm pick
    }
    gateLayout
    accountGateTick
    journalAdd info Вход "Показан экран входа"
    raise .gate
    raise .gate.shell
    catch {grab set .gate}
    focus .gate
}
proc accountLogin {} {
    if {![winfo exists .gate.shell.card.pad.box.sec]} return
    if {![info exists ::gatePin] || !$::gatePin} {
        gateReveal
        return
    }
    set id $::accountPick
    set secret [string trim [.gate.shell.card.pad.box.sec get]]
    if {$secret eq ""} {
        focus .gate.shell.card.pad.box.sec
        return
    }
    if {![accountCheck $id $secret]} {
        .gate.shell.card.pad.box.err configure -text "Неверный пароль или PIN"
        .gate.shell.card.pad.box.sec delete 0 end
        journalAdd warn Вход "Неверный пароль"
        gateShake 0
        return
    }
    if {![accountEnter $id]} {
        .gate.shell.card.pad.box.err configure -text "Не удалось открыть данные этого пользователя"
    }
}
proc accountCreate {} {
    if {![winfo exists .gate.shell.card.pad.box.name]} return
    set name [string trim [.gate.shell.card.pad.box.name get]]
    set a [.gate.shell.card.pad.box.sec get]
    set b [.gate.shell.card.pad.box.sec2 get]
    if {$name eq ""} {
        .gate.shell.card.pad.box.err configure -text "Введите имя"
        return
    }
    if {[string length $a] < 4} {
        .gate.shell.card.pad.box.err configure -text "Пароль или PIN — не короче 4 знаков"
        return
    }
    if {$a ne $b} {
        .gate.shell.card.pad.box.err configure -text "Пароль не совпал"
        return
    }
    set id u[clock seconds][format %03d [expr {abs([clock clicks]) % 1000}]]
    set salt [accountSalt]
    set hash [accountHash $salt $a]
    if {$hash eq ""} {
        .gate.shell.card.pad.box.err configure -text "Не удалось записать пароль"
        return
    }
    accountWriteMeta $id $name $salt $hash $::accountNewAvatar
    accountPrepareHome $id
    journalAdd info Вход "Создана учётка: $name"
    if {![accountEnter $id]} {
        .gate.shell.card.pad.box.err configure -text "Не удалось открыть данные этого пользователя"
    }
}
proc accountEditAvatar {a} {
    set ::accountEditAvatar $a
    set p .wsettings.in.b.page
    for {set i 0} {$i < 6} {incr i} {
        set c $p.avs.c$i
        if {![winfo exists $c]} continue
        accountDraw $c 48 $i $::user
        if {$i == $a} { $c create oval 1 1 46 46 -outline #f6f1ea -width 2 }
    }
}
proc accountSaveProfile {} {
    if {![info exists ::accountId] || $::accountId eq ""} return
    set p .wsettings.in.b.page
    set name [string trim [$p.name get]]
    if {$name eq ""} { return }
    array set m [accountMeta $::accountId]
    accountWriteMeta $::accountId $name $m(salt) $m(hash) $::accountEditAvatar
    set ::user $name
    set ::accountAvatar $::accountEditAvatar
    accountPaintWho
    notify "Учётка" "Имя и аватар сохранены"
}
proc accountSaveSecret {} {
    if {![info exists ::accountId] || $::accountId eq ""} return
    set p .wsettings.in.b.page
    set old [$p.old get]
    set a [$p.new1 get]
    set b [$p.new2 get]
    if {![accountCheck $::accountId $old]} {
        $p.err configure -text "Текущий пароль не подошёл"
        return
    }
    if {[string length $a] < 4} {
        $p.err configure -text "Новый пароль или PIN — не короче 4 знаков"
        return
    }
    if {$a ne $b} {
        $p.err configure -text "Новый пароль не совпал"
        return
    }
    array set m [accountMeta $::accountId]
    set salt [accountSalt]
    set hash [accountHash $salt $a]
    if {$hash eq ""} {
        $p.err configure -text "Не удалось записать пароль"
        return
    }
    accountWriteMeta $::accountId $m(name) $salt $hash $m(avatar)
    $p.old delete 0 end
    $p.new1 delete 0 end
    $p.new2 delete 0 end
    $p.err configure -text ""
    notify "Учётка" "Пароль изменён"
}
proc lockFonts {} {
    set ts 92
    if {$::SW < 1100} { set ts 68 }
    if {$::SW < 820} { set ts 48 }
    set ss [expr {$ts / 3}]
    if {$ss < 16} { set ss 16 }
    foreach {fn spec} [list \
        locktime [list -family "DejaVu Sans" -size $ts] \
        locksec [list -family "DejaVu Sans" -size $ss] \
        lockname [list -family "DejaVu Sans" -size 18 -weight bold] \
        lockbrand [list -family "DejaVu Sans" -size 11] \
        locktiny [list -family "DejaVu Sans" -size 9] \
        lockav [list -family "DejaVu Sans" -size 28 -weight bold]] {
        if {[catch {font create $fn {*}$spec}]} {
            font configure $fn {*}$spec
        }
    }
}
proc lockPretty {} {
    foreach line [split [readFile /etc/os-release 1500] \n] {
        if {[string match PRETTY_NAME=* $line]} {
            return [string trim [string range $line 12 end] \"]
        }
    }
    return "DeepOS"
}
proc lockWeatherText {} {
    if {![info exists ::weatherLine]} { return "" }
    set t [string trim $::weatherLine]
    if {$t eq ""} { return "" }
    foreach bad [list "Загрузка..." "Обновляю..." "Нет данных" "Сеть запрещена" "Геолокация запрещена"] {
        if {[string match ${bad}* $t]} { return "" }
    }
    return [string map {"+" " · "} $t]
}
proc lockGlow {c cx cy radius color strength} {
    set steps 12
    for {set i $steps} {$i >= 1} {incr i -1} {
        set rad [expr {$radius * $i / double($steps)}]
        set t [expr {$strength * (1.0 - ($i - 1) / double($steps))}]
        set col [mixHex $color #0f0f0f $t]
        $c create oval [expr {$cx - $rad}] [expr {$cy - $rad}] [expr {$cx + $rad}] [expr {$cy + $rad}] \
            -fill $col -outline {} -tags glow
    }
}
proc lockPaintBg {} {
    set c .lock.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    set h [winfo height $c]
    if {$w < 100 || $h < 100} {
        set w $::SW
        set h $::SH
    }
    $c delete glow
    lockGlow $c [expr {$w * 0.82}] [expr {$h * 0.08}] [expr {$w * 0.46}] #c4a27a 0.30
    lockGlow $c [expr {$w * 0.08}] [expr {$h * 0.92}] [expr {$w * 0.38}] #8a5a28 0.24
    lockGlow $c [expr {$w * 0.50}] [expr {$h * 0.46}] [expr {$w * 0.28}] #e4c4a0 0.07
}
proc lockPaintChrome {} {
    set c .lock.c
    if {![winfo exists $c]} return
    set w [winfo width $c]
    set h [winfo height $c]
    if {$w < 100 || $h < 100} {
        set w $::SW
        set h $::SH
    }
    $c delete chrome
    set now [clock seconds]
    set hhmm [clock format $now -format [timeFmt]]
    set sec [clock format $now -format "%S"]
    set day [string trim [clock format $now -format "%e"]]
    set months {января февраля марта апреля мая июня июля августа сентября октября ноября декабря}
    set days {воскресенье понедельник вторник среда четверг пятница суббота}
    set mon [lindex $months [expr {[clock format $now -format "%m"] - 1}]]
    set wday [lindex $days [clock format $now -format "%w"]]
    set year [clock format $now -format "%Y"]
    set date "$day $mon $year, $wday"
    $c create rectangle 32 22 42 32 -fill #e4c4a0 -outline {} -tags chrome
    $c create text 52 27 -anchor w -text "DeepOS" -fill #e4c4a0 -font lockbrand -tags chrome
    $c create text [expr {$w - 32}] 27 -anchor e -text "[lockPretty]   ·   Заблокировано" \
        -fill #8d8680 -font locktiny -tags chrome
    set yb [expr {$h - 150}]
    if {$h < 700} { set yb [expr {$h - 120}] }
    $c create text 64 $yb -anchor sw -text $hhmm -fill #f4f1ec -font locktime -tags chrome
    set tw [font measure locktime $hhmm]
    set th [font metrics locktime -linespace]
    $c create text [expr {64 + $tw + 16}] [expr {$yb - $th + [font metrics locksec -ascent] + 8}] \
        -anchor nw -text $sec -fill #e4c4a0 -font locksec -tags chrome
    $c create text 64 [expr {$yb + 18}] -anchor nw -text $date -fill #b9b2aa -font ui -tags chrome
    set wx [lockWeatherText]
    if {$wx ne ""} {
        $c create text 64 [expr {$yb + 46}] -anchor nw -text $wx -fill #e4c4a0 -font small -tags chrome
    }
    $c create text 32 [expr {$h - 28}] -anchor w -text "DeepOS" -fill #7a746e -font locktiny -tags chrome
    $c create text [expr {$w - 32}] [expr {$h - 28}] -anchor e -text "Enter  —  войти" \
        -fill #7a746e -font locktiny -tags chrome
}
proc lockLayout {} {
    if {![winfo exists .lock]} return
    lockFonts
    wm geometry .lock ${::SW}x${::SH}+0+0
    if {[winfo exists .lock.c]} {
        .lock.c configure -width $::SW -height $::SH
        place .lock.c -x 0 -y 0 -width $::SW -height $::SH
    }
    lockPaintBg
    lockPaintChrome
    if {![winfo exists .lock.shell]} return
    if {$::SW >= 1000} {
        place .lock.shell -x [expr {$::SW - 56}] -rely 0.48 -anchor e -width 360
    } else {
        place .lock.shell -relx 0.5 -rely 0.62 -anchor center -width 360
    }
    raise .lock.shell
}
proc lockDrawAvatar {{hot 0}} {
    set c .lock.shell.card.pad.av
    if {![winfo exists $c]} return
    $c delete all
    set colors [accountColors]
    set avatar 0
    if {[info exists ::accountAvatar]} { set avatar $::accountAvatar }
    if {![string is integer -strict $avatar]} { set avatar 0 }
    set fill [lindex $colors [expr {$avatar % [llength $colors]}]]
    if {$hot} {
        $c create oval 2 2 106 106 -outline #e4c4a0 -width 2
    } else {
        $c create oval 6 6 102 102 -outline #5a4632 -width 1
    }
    $c create oval 14 14 94 94 -fill $fill -outline {}
    $c create text 54 54 -text [accountInitial $::user] -fill #141414 -font lockav
}
proc lockShowPin {} {
    if {![winfo exists .lock.shell.card.pad.pin]} return
    set ::lockPin 1
    pack .lock.shell.card.pad.pin -fill x -pady {18 0}
    if {[winfo exists .lock.shell.card.pad.status]} {
        .lock.shell.card.pad.status configure -text ""
    }
    focus .lock.shell.card.pad.e
}
proc lockShake {n} {
    if {![winfo exists .lock.shell]} return
    set dx [lindex {0 -10 10 -7 7 -3 0} $n]
    if {$dx eq ""} { set dx 0 }
    if {$::SW >= 1000} {
        place .lock.shell -x [expr {$::SW - 56 + $dx}] -rely 0.48 -anchor e -width 360
    } else {
        place .lock.shell -relx 0.5 -x $dx -rely 0.62 -anchor center -width 360
    }
    if {$n < 6} { after 36 [list lockShake [expr {$n + 1}]] }
}
proc lockSession {} {
    hideStart
    journalAdd info Экран "Экран заблокирован"
    if {![info exists ::accountId] || $::accountId eq ""} {
        accountGate
        return
    }
    if {[info exists ::lockTick]} {
        after cancel $::lockTick
        unset ::lockTick
    }
    if {[winfo exists .lock]} { destroy .lock }
    set ::lockPin 0
    lockFonts
    toplevel .lock
    wm overrideredirect .lock 1
    wm geometry .lock ${::SW}x${::SH}+0+0
    .lock configure -bg #0f0f0f
    canvas .lock.c -bg #0f0f0f -highlightthickness 0 -bd 0
    place .lock.c -x 0 -y 0 -width $::SW -height $::SH
    frame .lock.shell -bg #3a342c
    frame .lock.shell.card -bg #1a1714
    pack .lock.shell.card -fill both -expand 1 -padx 1 -pady 1
    frame .lock.shell.card.pad -bg #1a1714
    pack .lock.shell.card.pad -fill both -expand 1 -padx 28 -pady 28
    canvas .lock.shell.card.pad.av -width 108 -height 108 -bg #1a1714 -highlightthickness 0 -cursor hand2
    pack .lock.shell.card.pad.av -pady {8 0}
    lockDrawAvatar
    label .lock.shell.card.pad.name -text $::user -bg #1a1714 -fg #f4f1ec -font lockname
    pack .lock.shell.card.pad.name -pady {8 2}
    label .lock.shell.card.pad.status -text "НАЖМИТЕ НА АВАТАР, ЧТОБЫ ВОЙТИ" -bg #1a1714 -fg #8d8680 -font locktiny
    pack .lock.shell.card.pad.status
    frame .lock.shell.card.pad.pin -bg #1a1714
    frame .lock.shell.card.pad.pin.row -bg #2a241e
    pack .lock.shell.card.pad.pin.row -fill x
    entry .lock.shell.card.pad.e -show * -bg #14120f -fg #f4f1ec -insertbackground #e4c4a0 \
        -font ui -relief flat -bd 0 -highlightthickness 0
    pack .lock.shell.card.pad.e -in .lock.shell.card.pad.pin.row -side left -fill x -expand 1 -padx 1 -pady 1 -ipady 8 -ipadx 12
    label .lock.shell.card.pad.go -text "Войти" -bg #e4c4a0 -fg #141414 -font uib -padx 14 -pady 8 -cursor hand2
    pack .lock.shell.card.pad.go -in .lock.shell.card.pad.pin.row -side right -padx 4 -pady 4
    label .lock.shell.card.pad.err -text "" -bg #1a1714 -fg #e07b7b -font small -wraplength 280 -justify left
    pack .lock.shell.card.pad.err -in .lock.shell.card.pad.pin -fill x -pady {8 0}
    bind .lock.shell.card.pad.av <Button-1> lockShowPin
    bind .lock.shell.card.pad.av <Enter> { lockDrawAvatar 1 }
    bind .lock.shell.card.pad.av <Leave> { lockDrawAvatar 0 }
    bind .lock.shell.card.pad.go <Button-1> unlockSession
    bind .lock.shell.card.pad.go <Enter> { .lock.shell.card.pad.go configure -bg #f0d2b4 }
    bind .lock.shell.card.pad.go <Leave> { .lock.shell.card.pad.go configure -bg #e4c4a0 }
    bind .lock.shell.card.pad.e <Return> { unlockSession; break }
    bind .lock.shell.card.pad.e <Escape> break
    bind .lock <Return> unlockSession
    bind .lock <Escape> break
    lockLayout
    raise .lock
    raise .lock.shell
    catch {grab set .lock}
    focus .lock
    set ::lockTick [after 1000 lockTick]
}
proc lockTick {} {
    if {![winfo exists .lock.c]} return
    lockPaintChrome
    set ::lockTick [after 1000 lockTick]
}
proc unlockSession {} {
    if {![winfo exists .lock.shell.card.pad.e]} return
    if {!$::lockPin} {
        lockShowPin
        return
    }
    set secret [string trim [.lock.shell.card.pad.e get]]
    if {$secret eq ""} {
        focus .lock.shell.card.pad.e
        return
    }
    if {![accountCheck $::accountId $secret]} {
        .lock.shell.card.pad.err configure -text "Неверный пароль или PIN"
        .lock.shell.card.pad.e delete 0 end
        focus .lock.shell.card.pad.e
        lockShake 0
        return
    }
    if {[info exists ::lockTick]} {
        after cancel $::lockTick
        unset ::lockTick
    }
    catch {grab release .lock}
    destroy .lock
    focus -force .desk
}
proc doLogout {} {
    hideStart
    journalAdd info Вход "Выход: $::user"
    accountCloseApps
    if {![accountUnmount]} {
        notify "Учётка" "Не удалось закрыть данные. Закройте программы и попробуйте снова."
        return
    }
    set ::accountId ""
    set ::user ""
    set ::accountAvatar 0
    accountGate
}

bind .desk.bg <Button-1> {hideStart; hideCtx; filesMenuHide}
bind .desk.bg <Button-3> {showCtx %X %Y}
bind .desk.bar <Button-1> {hideStart; hideCtx}
proc showCtx {x y} {
    set rx [expr {$x - [winfo rootx .desk]}]
    set ry [expr {$y - [winfo rooty .desk]}]
    if {$rx > [expr {$::SW - 220}]} { set rx [expr {$::SW - 220}] }
    if {$ry > [expr {$::SH - $::BARH - 200}]} { set ry [expr {$::SH - $::BARH - 200}] }
    if {$rx < 4} { set rx 4 }
    if {$ry < 4} { set ry 4 }
    place .desk.ctx -x $rx -y $ry
    raise .desk.ctx
}

proc fitDesktop {} {
    if {[info exists ::fitWait]} { after cancel $::fitWait }
    set w [winfo screenwidth .desk]
    set h [winfo screenheight .desk]
    if {$w > 200 && $h > 200 && (![info exists ::lastFit] || $::lastFit ne "$w $h")} {
        set ::lastFit "$w $h"
        set ::SW $w
        set ::SH $h
        wm geometry .desk ${w}x${h}+0+0
        place .desk.bg -x 0 -y 0 -relx 0 -rely 0 -relwidth 0 -relheight 0 -width $w -height $h -anchor nw
        place .desk.bar -x 0 -y [expr {$h - $::BARH}] -relx 0 -rely 0 -relwidth 0 -relheight 0 \
            -width $w -height $::BARH -anchor nw
        raise .desk.bar
        raiseDeskIcons
        doPaintPins
        if {[winfo exists .gate]} { gateLayout }
        if {[winfo exists .lock]} { lockLayout }
    }
    clockRaise
    set ::fitWait [after 1000 fitDesktop]
}

proc mixHex {a b t} {
    scan $a "#%2x%2x%2x" ar ag ab
    scan $b "#%2x%2x%2x" br bg bb
    set t [expr {double($t)}]
    if {$t < 0} { set t 0.0 }
    if {$t > 1} { set t 1.0 }
    set r [expr {int($br + ($ar - $br) * $t)}]
    set g [expr {int($bg + ($ag - $bg) * $t)}]
    set bl [expr {int($bb + ($ab - $bb) * $t)}]
    return [format "#%02x%02x%02x" $r $g $bl]
}
proc clockHideSet {} { catch { destroy .clkset } }
proc clockRaise {} {
    if {[winfo exists .dclock]} { raise .dclock }
    if {[winfo exists .wx]} { raise .wx }
    if {[winfo exists .mag]} { raise .mag }
    if {[winfo exists .osk]} { raise .osk }
    if {[winfo exists .speak]} { raise .speak }
    if {[info exists ::toastTop]} {
        foreach w $::toastTop {
            if {[winfo exists $w]} { raise $w }
        }
    }
    if {[winfo exists .clkset]} { raise .clkset }
    if {[winfo exists .ask]} { raise .ask }
    if {[winfo exists .lock] && [winfo ismapped .lock]} { raise .lock }
    if {[winfo exists .gate] && [winfo ismapped .gate]} { raise .gate }
}
proc clockLoad {} {
    set home /root
    if {[info exists ::env(HOME)] && $::env(HOME) ne ""} { set home $::env(HOME) }
    set ::clockFile [file join $home .config deepos clock.json]
    set ::clkPreset default
    set ::clkSeconds 1
    set ::clkSize 140
    set ::clkOpacity 0.30
    if {![file exists $::clockFile]} {
        clockSave
        return
    }
    set data [readFile $::clockFile 2000]
    if {[regexp {"preset"[[:space:]]*:[[:space:]]*"(default|aesthetic|accessible)"} $data -> v]} {
        set ::clkPreset $v
    }
    if {[regexp {"seconds"[[:space:]]*:[[:space:]]*(true|false)} $data -> v]} {
        set ::clkSeconds [expr {$v eq "true"}]
    }
    if {[regexp {"size"[[:space:]]*:[[:space:]]*([0-9]+)} $data -> v]} {
        set ::clkSize $v
    }
    if {[regexp {"opacity"[[:space:]]*:[[:space:]]*([0-9.]+)} $data -> v]} {
        set ::clkOpacity $v
    }
    set ::clkPlaced 0
    if {[regexp {"x"[[:space:]]*:[[:space:]]*(-?[0-9]+)} $data -> vx] && [regexp {"y"[[:space:]]*:[[:space:]]*(-?[0-9]+)} $data -> vy]} {
        set ::clkX $vx
        set ::clkY $vy
        set ::clkPlaced 1
    }
    if {$::clkSize < 80} { set ::clkSize 140 }
    if {$::clkSize > 220} { set ::clkSize 220 }
    if {$::clkOpacity < 0.2} { set ::clkOpacity 0.30 }
    if {$::clkOpacity > 1.0} { set ::clkOpacity 1.0 }
}
proc clockSave {} {
    file mkdir [file dirname $::clockFile]
    set sec true
    if {!$::clkSeconds} { set sec false }
    set preset default
    if {$::clkPreset eq "aesthetic" || $::clkPreset eq "accessible"} { set preset $::clkPreset }
    set fh [open $::clockFile w]
    puts $fh "\{"
    puts $fh "  \"preset\": \"$preset\","
    puts $fh "  \"font\": \"Unbounded SemiBold\","
    puts $fh "  \"seconds\": $sec,"
    puts $fh "  \"size\": [expr {int($::clkSize)}],"
    puts $fh "  \"opacity\": [format %.2f $::clkOpacity],"
    if {[info exists ::clkPlaced] && $::clkPlaced} {
        puts $fh "  \"x\": [expr {int($::clkX)}],"
        puts $fh "  \"y\": [expr {int($::clkY)}],"
    }
    puts $fh "\}"
    close $fh
}
proc clockStyle {} {
    set px [expr {int($::clkSize)}]
    set neg [expr {0 - $px}]
    if {[lsearch -exact [font names] clkface] >= 0} {
        font configure clkface -family "Unbounded" -size $neg -weight normal
    } else {
        font create clkface -family "Unbounded" -size $neg -weight normal
    }
    set got [font actual clkface -family]
    if {![string match -nocase *unbounded* $got]} {
        font configure clkface -family "DejaVu Sans" -size $neg -weight bold
        if {![info exists ::clkFontWarned]} {
            set ::clkFontWarned 1
            catch { exec /bin/sh -c "echo DEEPOS_FONT_FALLBACK > /dev/ttyS0" }
        }
    }
    clockRedraw
}
proc clockRedraw {} {
    if {![winfo exists .dclock.c]} return
    set text [clock format [clock seconds] -format [timeFmt 1]]
    set pad 6
    set tw [font measure clkface $text]
    set th [font metrics clkface -linespace]
    set cw [expr {$tw + $pad * 2}]
    set ch [expr {$th + $pad * 2}]
    .dclock configure -bg #111111
    .dclock.c configure -width $cw -height $ch -bg #111111
    catch { .dclock.c delete shadow }
    set face #ffffff
    if {[info exists ::set_theme] && $::set_theme eq "contrast"} { set face #ffff00 }
    .dclock.c itemconfigure face -text $text -fill $face -font clkface
    .dclock.c coords face $pad $pad
    if {[info exists ::clkPlaced] && $::clkPlaced} {
        set x $::clkX
        set y $::clkY
    } else {
        set x [expr {$::SW - $cw - 28}]
        set y [expr {$::SH - $::BARH - $ch - 18}]
    }
    if {$x < 8} { set x 8 }
    if {$y < 8} { set y 8 }
    if {$x > $::SW - 40} { set x [expr {$::SW - 40}] }
    if {$y > $::SH - $::BARH - 24} { set y [expr {$::SH - $::BARH - 24}] }
    set ::clkX $x
    set ::clkY $y
    wm geometry .dclock ${cw}x${ch}+${x}+${y}
    if {[winfo ismapped .dclock]} {
        if {[catch { wm attributes .dclock -alpha $::clkOpacity }]} {
            if {![info exists ::clkAlphaWarned]} {
                set ::clkAlphaWarned 1
                catch { exec /bin/sh -c "echo DEEPOS_ALPHA_FAIL > /dev/ttyS0" }
            }
        }
    }
    clockRaise
}
proc clockTick {} {
    clockRedraw
    set ::clockWait [after 1000 clockTick]
}
proc clockCommit {} {
    clockSave
    clockStyle
    if {[winfo exists .clkset]} { clockPaintSet }
}
proc clockMark {w on} {
    if {![winfo exists $w]} return
    if {$on} {
        $w configure -bg #e4c4a0 -fg #1c1612
    } else {
        $w configure -bg #1c1c1c -fg #f3f3f3
    }
}
proc clockPaintSet {} {
    if {![winfo exists .clkset]} return
    clockMark .clkset.in.aes [expr {$::clkPreset eq "aesthetic"}]
    clockMark .clkset.in.acc [expr {$::clkPreset eq "accessible"}]
}
proc clockPickPreset {name} {
    set ::clkPreset $name
    if {$name eq "accessible"} {
        set ::clkSize 190
        set ::clkOpacity 0.90
    } else {
        set ::clkSize 130
        set ::clkOpacity 0.30
    }
    clockHideSet
    clockCommit
}
proc clockShowSet {} {
    if {[winfo exists .clkset]} {
        clockHideSet
        return
    }
    toplevel .clkset
    wm overrideredirect .clkset 1
    .clkset configure -bg #3a3a3a
    frame .clkset.in -bg #1c1c1c
    pack .clkset.in -fill both -expand 1 -padx 1 -pady 1
    label .clkset.in.t -text "Пресет" -bg #1c1c1c -fg #9a9a9a -font tiny -anchor w
    pack .clkset.in.t -fill x -padx 14 -pady {10 2}
    label .clkset.in.aes -text "Эстетичный" -bg #1c1c1c -fg #f3f3f3 -font task -anchor w -padx 14 -pady 8 -cursor hand2
    label .clkset.in.acc -text "Доступный" -bg #1c1c1c -fg #f3f3f3 -font task -anchor w -padx 14 -pady 8 -cursor hand2
    pack .clkset.in.aes .clkset.in.acc -fill x
    bind .clkset.in.aes <Button-1> { clockPickPreset aesthetic }
    bind .clkset.in.acc <Button-1> { clockPickPreset accessible }
    clockPaintSet
    update idletasks
    set pw 210
    set ph [winfo reqheight .clkset]
    set x [expr {[winfo x .dclock] + [winfo width .dclock] - $pw}]
    set y [expr {[winfo y .dclock] - $ph - 8}]
    if {$x < 8} { set x 8 }
    if {$y < 8} { set y 8 }
    wm geometry .clkset ${pw}x${ph}+${x}+${y}
    clockRaise
    bind .clkset <Escape> clockHideSet
}
set ::calMonths {январь февраль март апрель май июнь июль август сентябрь октябрь ноябрь декабрь}
set ::calGen {января февраля марта апреля мая июня июля августа сентября октября ноября декабря}
set ::calWdays {Пн Вт Ср Чт Пт Сб Вс}
set ::calLongDays {понедельник вторник среда четверг пятница суббота воскресенье}
proc calLong {stamp} {
    set day [scan [clock format $stamp -format "%d"] "%d"]
    set mi [expr {[scan [clock format $stamp -format "%m"] "%d"] - 1}]
    set wd [expr {[scan [clock format $stamp -format "%u"] "%d"] - 1}]
    return "[lindex $::calLongDays $wd], $day [lindex $::calGen $mi] [clock format $stamp -format "%Y"]"
}
proc calShift {dir} {
    set m [scan $::calMon "%d"]
    set y [scan $::calYear "%d"]
    incr m $dir
    if {$m < 1} { set m 12; incr y -1 }
    if {$m > 12} { set m 1; incr y 1 }
    set ::calMon [format "%02d" $m]
    set ::calYear $y
    calRender
}
proc calPick {day} {
    set ::calSel [clock scan [format "%s-%s-%02d" $::calYear $::calMon $day] -format "%Y-%m-%d"]
    calRender
}
proc calToday {} {
    set now [clock seconds]
    set ::calYear [clock format $now -format "%Y"]
    set ::calMon [clock format $now -format "%m"]
    set ::calSel [clock scan [clock format $now -format "%Y-%m-%d"] -format "%Y-%m-%d"]
    calRender
}
proc calRender {} {
    set w .wcalendar
    if {![winfo exists $w.in.b.grid]} return
    set b $w.in.b
    set mi [expr {[scan $::calMon "%d"] - 1}]
    $b.head.title configure -text "[lindex $::calMonths $mi] $::calYear"
    foreach child [winfo children $b.grid] { destroy $child }
    set first [clock scan "$::calYear-$::calMon-01" -format "%Y-%m-%d"]
    set lead [expr {[scan [clock format $first -format "%u"] "%d"] - 1}]
    set last [clock add [clock add $first 1 month] -1 day]
    set dim [scan [clock format $last -format "%d"] "%d"]
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set sel ""
    if {[info exists ::calSel]} { set sel [clock format $::calSel -format "%Y-%m-%d"] }
    set col $lead
    set row 0
    for {set day 1} {$day <= $dim} {incr day} {
        set key [format "%s-%s-%02d" $::calYear $::calMon $day]
        set bg #1c1c1c
        set fg #f4f4f4
        if {$col >= 5} { set fg #c8bbaa }
        if {$key eq $sel} { set bg #3a3328; set fg #f7f4ef }
        if {$key eq $today} { set bg #e4c4a0; set fg #1c1612 }
        set cell $b.grid.d$day
        label $cell -text $day -bg $bg -fg $fg -font task -width 4 -pady 8 -cursor hand2
        grid $cell -row $row -column $col -padx 3 -pady 3 -sticky nsew
        bind $cell <Button-1> [list calPick $day]
        incr col
        if {$col >= 7} { set col 0; incr row }
    }
    if {[info exists ::calSel]} {
        $b.info configure -text [calLong $::calSel]
    }
}
proc openCalendar {} {
    hideStart
    clockHideSet
    noteRecent "Календарь" openCalendar
    set w [newWindow calendar "Календарь" 520 560]
    set b $w.in.b
    if {[winfo exists $b.grid]} {
        calRender
        return
    }
    set now [clock seconds]
    set ::calYear [clock format $now -format "%Y"]
    set ::calMon [clock format $now -format "%m"]
    set ::calSel [clock scan [clock format $now -format "%Y-%m-%d"] -format "%Y-%m-%d"]
    frame $b.head -bg $::MICA
    pack $b.head -fill x -padx 18 -pady {16 8}
    label $b.head.prev -text "<" -bg #2a2a2a -fg #f3f3f3 -font ui -padx 12 -pady 4 -cursor hand2
    label $b.head.next -text ">" -bg #2a2a2a -fg #f3f3f3 -font ui -padx 12 -pady 4 -cursor hand2
    label $b.head.title -text "" -bg $::MICA -fg #f7f4ef -font uib
    pack $b.head.prev -side left
    pack $b.head.next -side right
    pack $b.head.title -side left -fill x -expand 1 -padx 12
    bind $b.head.prev <Button-1> { calShift -1 }
    bind $b.head.next <Button-1> { calShift 1 }
    frame $b.week -bg $::MICA
    pack $b.week -fill x -padx 18
    set i 0
    foreach name $::calWdays {
        label $b.week.w$i -text $name -bg $::MICA -fg #9a9a9a -font tiny -width 4
        grid $b.week.w$i -row 0 -column $i -padx 3
        incr i
    }
    frame $b.grid -bg $::MICA
    pack $b.grid -fill both -expand 1 -padx 18 -pady 8
    for {set c 0} {$c < 7} {incr c} { grid columnconfigure $b.grid $c -weight 1 -uniform day }
    label $b.info -text "" -bg $::MICA -fg #f7f4ef -font ui -anchor w
    pack $b.info -fill x -padx 22 -pady {4 6}
    label $b.today -text "Сегодня" -bg #e4c4a0 -fg #1c1612 -font task -padx 14 -pady 6 -cursor hand2
    pack $b.today -anchor w -padx 22 -pady {0 16}
    bind $b.today <Button-1> calToday
    calRender
}
proc clockPress {x y} {
    set ::clkGrab 1
    set ::clkDrag 0
    set ::clkPX $x
    set ::clkPY $y
    set ::clkOX [winfo x .dclock]
    set ::clkOY [winfo y .dclock]
}
proc clockDrag {x y} {
    if {![info exists ::clkGrab] || !$::clkGrab} return
    if {![winfo exists .dclock]} { set ::clkGrab 0; return }
    set dx [expr {$x - $::clkPX}]
    set dy [expr {$y - $::clkPY}]
    if {!$::clkDrag} {
        if {abs($dx) + abs($dy) < 4} return
        set ::clkDrag 1
    }
    set nx [expr {$::clkOX + $dx}]
    set ny [expr {$::clkOY + $dy}]
    set cw [winfo width .dclock]
    set ch [winfo height .dclock]
    if {$nx < 0} { set nx 0 }
    if {$ny < 0} { set ny 0 }
    if {$nx > $::SW - $cw} { set nx [expr {$::SW - $cw}] }
    if {$ny > $::SH - $::BARH - $ch} { set ny [expr {$::SH - $::BARH - $ch}] }
    set ::clkX $nx
    set ::clkY $ny
    set ::clkPlaced 1
    wm geometry .dclock +$nx+$ny
}
proc weatherPlace {} {
    if {![winfo exists .wx]} return
    wm geometry .wx 320x96+[expr {$::SW - 340}]+18
}
proc weatherShow {text} {
    set ::weatherLine $text
    set b .wx.in.b
    if {[winfo exists $b]} {
        $b configure -text $text
    }
    if {[winfo exists .lock.c]} { lockPaintChrome }
    if {[winfo exists .gate.c]} { gatePaintChrome }
}
proc weatherDone {out} {
    set line [string trim [lindex [split $out \n] 0]]
    if {$line eq "" || [string match -nocase "*error*" $line] || [string match -nocase "*could not*" $line]} {
        weatherShow "Нет данных. Нажмите, чтобы повторить."
        return
    }
    weatherShow $line
}
proc weatherFetch {} {
    if {![permAllows net]} {
        weatherShow "Сеть запрещена в разрешениях"
        journalAdd warn Разрешения "Погода не обновлена: нет доступа к сети"
        return
    }
    if {![permAllows geo]} {
        weatherShow "Геолокация запрещена в разрешениях"
        journalAdd warn Разрешения "Погода не обновлена: нет геолокации"
        return
    }
    weatherShow "Обновляю..."
    jobStart [list | /bin/sh -c "curl -fsS --max-time 8 -A curl 'https://wttr.in/?format=%l:+%t+%C'"] weatherDone
}
proc weatherInit {} {
    toplevel .wx
    wm overrideredirect .wx 1
    .wx configure -bg #3a3a3a
    frame .wx.in -bg $::BAR
    pack .wx.in -fill both -expand 1 -padx 1 -pady 1
    label .wx.in.t -text "Погода" -bg $::BAR -fg $::ACCENT -font small -anchor w
    label .wx.in.b -text "Загрузка..." -bg $::BAR -fg #f3f3f3 -font ui -anchor w -wraplength 290 -justify left
    pack .wx.in.t -fill x -padx 12 -pady {8 0}
    pack .wx.in.b -fill x -padx 12 -pady {2 8}
    weatherPlace
    bind .wx <Button-1> weatherFetch
    bind .wx.in <Button-1> weatherFetch
    bind .wx.in.t <Button-1> weatherFetch
    bind .wx.in.b <Button-1> weatherFetch
    after 1500 weatherTick
}
proc weatherTick {} {
    if {![info exists ::bootWeather] || $::bootWeather} { weatherFetch }
    after 1200000 weatherTick
}
proc clockInit {} {
    clockLoad
    toplevel .dclock
    wm overrideredirect .dclock 1
    .dclock configure -bg #111111
    canvas .dclock.c -bg #111111 -highlightthickness 0 -bd 0 -cursor hand2
    pack .dclock.c
    .dclock.c create text 6 6 -anchor nw -tag face -fill #ffffff
    bind .dclock.c <Button-1> { clockPress %X %Y }
    bind .dclock <Button-1> { clockPress %X %Y }
    bind .dclock.c <Button-3> clockShowSet
    bind .dclock <Button-3> clockShowSet
    clockStyle
    clockTick
}

settingsLoad
paintPins
paintDeskIcons
refreshTray
fitDesktop
if {[info exists ::set_host] && $::set_host ne ""} {
    catch { exec hostname $::set_host }
}
if {$::set_wall eq "image" && $::set_wallfile ne "" && [file exists $::set_wallfile]} {
    catch { image create photo ::wallimg -file $::set_wallfile }
}
themeApply
fontApply
cursorApply
recentLoad
if {[info exists ::set_trashboot] && $::set_trashboot eq "1"} { trashQuietEmpty }
if {[info exists ::set_speak] && $::set_speak eq "1"} { speakShow "Озвучка включена" }
clockInit
weatherInit
if {[info exists ::set_sound] && $::set_sound ne "off"} { after 2500 { soundPlay welcome } }
after 300 startBuildIndex
accountGate
