#!/usr/bin/env bash

# Usage:
#   ./group_stats_multi.sh group1.csv group2.csv ...

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 file1.csv [file2.csv ...]" >&2
    exit 1
fi

read -p "Enter shooting distance in yards (for MOA calc): " dist_yd

if ! [[ "$dist_yd" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    echo "Error: distance must be numeric." >&2
    exit 1
fi

read -p "Enter base name for output files (no extension): " outbase
outbase="${outbase//[[:space:]]/}"

if [[ -z "$outbase" ]]; then
    echo "Error: output base name cannot be empty." >&2
    exit 1
fi

pngfile="${outbase}.png"
outfile="${outbase}.output.txt"

echo "Output PNG will be:     $pngfile"
echo "Output stats will be:   $outfile"

# Arrays to hold per-group stats
declare -a groups bases counts centers_x centers_y meanRs avgDxs avgDys tmpfiles

# File with all points from all groups (for overall stats)
tmpAll=$(mktemp)

############################################
# Process one group file
############################################
process_group() {
    local csv="$1"
    local tmpdata="$2"

    # Extract numeric rows into tmpdata
    awk -F',' '
        function isnumeric(v){ return (v ~ /^-?[0-9]*\.?[0-9]+$/) }
        {
            gsub(/^[ \t]+|[ \t]+$/, "", $1)
            gsub(/^[ \t]+|[ \t]+$/, "", $2)
            if (isnumeric($1) && isnumeric($2)) print $1, $2
        }
    ' "$csv" > "$tmpdata"

    # Append to global "all points" file
    cat "$tmpdata" >> "$tmpAll"

    # Compute center (Cx, Cy) and count for this group
    read Cx Cy count <<EOF
$(awk '
    {
        x += $1; y += $2; n++;
    }
    END {
        if (n>0) printf "%.6f %.6f %d\n", x/n, y/n, n;
    }
' "$tmpdata")
EOF

    if [[ -z "$count" || "$count" -eq 0 ]]; then
        echo "Warning: no numeric rows found in '$csv' (skipping in stats)." >&2
        Cx=0; Cy=0; count=0
    fi

    # Compute mean radius and avg |dx|, |dy| for this group
    read meanR avgDx avgDy <<EOF
$(awk -v cx="$Cx" -v cy="$Cy" '
    {
        dx = $1 - cx;
        dy = $2 - cy;
        r  = sqrt(dx*dx + dy*dy);

        sumR  += r;
        sumDx += (dx<0 ? -dx : dx);
        sumDy += (dy<0 ? -dy : dy);
        n++;
    }
    END {
        if (n>0)
            printf "%.6f %.6f %.6f\n", sumR/n, sumDx/n, sumDy/n;
        else
            printf "0 0 0\n";
    }
' "$tmpdata")
EOF

    GROUP_CX="$Cx"
    GROUP_CY="$Cy"
    GROUP_COUNT="$count"
    GROUP_MR="$meanR"
    GROUP_AVGDX="$avgDx"
    GROUP_AVGDY="$avgDy"
}

############################################
# Loop over input group files
############################################
i=0
for csv in "$@"; do
    if [[ ! -f "$csv" ]]; then
        echo "Warning: file '$csv' not found, skipping." >&2
        continue
    fi

    fname="${csv##*/}"
    base="${fname%.*}"
    tmpdata=$(mktemp "/tmp/group_${base}.XXXXXX")

    process_group "$csv" "$tmpdata"

    groups[i]="$fname"
    bases[i]="$base"
    counts[i]="$GROUP_COUNT"
    centers_x[i]="$GROUP_CX"
    centers_y[i]="$GROUP_CY"
    meanRs[i]="$GROUP_MR"
    avgDxs[i]="$GROUP_AVGDX"
    avgDys[i]="$GROUP_AVGDY"
    tmpfiles[i]="$tmpdata"

    ((i++))
done

num_groups=${#tmpfiles[@]}

if [[ "$num_groups" -eq 0 ]]; then
    echo "Error: no valid groups to process." >&2
    rm -f "$tmpAll"
    exit 1
fi

############################################
# Overall stats for all points
############################################
read CxAll CyAll countAll <<EOF
$(awk '
    {
        x += $1; y += $2; n++;
    }
    END {
        if (n>0) printf "%.6f %.6f %d\n", x/n, y/n, n;
    }
' "$tmpAll")
EOF

meanRAll=$(awk -v cx="$CxAll" -v cy="$CyAll" '
    {
        dx = $1 - cx;
        dy = $2 - cy;
        r  = sqrt(dx*dx + dy*dy);
        sumR += r;
        n++;
    }
    END {
        if (n>0) printf "%.6f\n", sumR/n;
    }
' "$tmpAll")

meanRAll_MOA=$(awk -v r="$meanRAll" -v d="$dist_yd" 'BEGIN {
    printf "%.4f", (r * 95.493) / d;
}')

############################################
# Build a gnuplot script on the fly
############################################
gpscript=$(mktemp)

{
    echo "set terminal pngcairo size 800,800"
    echo "set output '${pngfile}'"
    echo "set title '${outbase}'"
    echo "set xlabel 'X'"
    echo "set ylabel 'Y'"
    echo "set grid"
    echo "set size square"

    # 4 x 4 window centered on overall group center
    echo "set xrange [${CxAll}-4:${CxAll}+4]"
    echo "set yrange [${CyAll}-4:${CyAll}+4]"

    # Overall mean radius circle (red)
    echo "set object 1 circle at ${CxAll},${CyAll} size ${meanRAll} front lw 2 lc rgb 'red'"

    # Labels
    echo "set label 1 sprintf('Overall mean radius = %.3f', ${meanRAll}) at graph 0.02,0.96 front"
    echo "set label 2 sprintf('Overall center = (%.3f, %.3f)', ${CxAll}, ${CyAll}) at graph 0.02,0.90 front"

    # 1x1 crosshair centered at origin
    echo "set arrow 2 from -0.5,0 to 0.5,0 nohead lw 1 lc rgb 'black'"
    echo "set arrow 3 from 0,-0.5 to 0,0.5 nohead lw 1 lc rgb 'black'"

    # Per-group mean-radius circles, colored to match group color (lc index)
    for idx in "${!groups[@]}"; do
        if [[ "${counts[$idx]}" -gt 0 ]]; then
            objnum=$((20 + idx))
            cx="${centers_x[$idx]}"
            cy="${centers_y[$idx]}"
            mr="${meanRs[$idx]}"
            color_idx=$((idx + 1))   # use color index
            echo "set object ${objnum} circle at ${cx},${cy} size ${mr} front lw 2 lc ${color_idx}"
        fi
    done

    # Build plot command
    echo -n "plot "
    first=1
    for idx in "${!tmpfiles[@]}"; do
        if [[ "${counts[$idx]}" -le 0 ]]; then
            continue
        fi
        tf=${tmpfiles[$idx]}
        title="${bases[$idx]} (MR=${meanRs[$idx]})"
        color_idx=$((idx + 1))
        pt=$((7 + idx))

        if [[ $first -eq 0 ]]; then
            echo -n ", "
        fi
        echo -n "'$tf' using 1:2 with points pt $pt ps 1.5 lc ${color_idx} title '$title'"
        first=0
    done

    # Add overall center as a final series
    echo ", '-' using 1:2 with points pt 4 ps 2 lc -1 title 'Overall Center'"
    echo "${CxAll} ${CyAll}"
    echo "e"
} > "$gpscript"

gnuplot "$gpscript"

############################################
# Write stats to output file
############################################
{
    echo "Output base name:       ${outbase}"
    echo "Shooting distance (yd): ${dist_yd}"
    echo

    echo "PER-GROUP STATS"
    echo "----------------"
    for idx in "${!groups[@]}"; do
        if [[ "${counts[$idx]}" -le 0 ]]; then
            continue
        fi
        echo "Group:            ${groups[$idx]}"
        echo "  Points:         ${counts[$idx]}"
        echo "  Center (Xc,Yc): (${centers_x[$idx]}, ${centers_y[$idx]})"
        echo "  Mean radius:    ${meanRs[$idx]}"
        echo "  Avg |X-Xc|:     ${avgDxs[$idx]}"
        echo "  Avg |Y-Yc|:     ${avgDys[$idx]}"
        echo
    done

    echo "OVERALL STATS (all points combined)"
    echo "-----------------------------------"
    echo "Total points:     ${countAll}"
    echo "Center (Xc,Yc):   (${CxAll}, ${CyAll})"
    echo "Mean radius:      ${meanRAll}"
    echo "Mean radius MOA:  ${meanRAll_MOA}  (at ${dist_yd} yards)"
    echo
    echo "Plot saved:       ${pngfile}"
} > "$outfile"

############################################
# Cleanup
############################################
rm -f "$tmpAll" "$gpscript"
for tf in "${tmpfiles[@]}"; do
    rm -f "$tf"
done

echo "Combined plot:    ${pngfile}"
echo "Stats file:       ${outfile}"
