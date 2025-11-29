#!/bin/bash

# This program calculates the standard deviation of a set of
# x,y coordinates stored in a text file.  Two numbers per line 
# separated by a space.  Will be used for calculating spread 
# on target, data input from engauge.  Output to stdout and 
# appended to Outfile and appended to file GraphData.Series 
# for graphing.  Best if Datafile is named by the number of 
# grains in the load without any .suffix.
Datapath=./Targets
Cont=y
echo "Please enter the series # for your targets"
echo "so that the data for plotting can be stored."
read Series
echo ""
Outfile=$Datapath/Deviation.$Series
while [ $Cont != "n" ]
do
dir $Datapath
echo ""
    echo "Please enter the name of the data file (without .csv) in $Datapath/ :"
#    echo "(Best to use number of grains in load.)"
read Datafile   					 # enter file
Sumx=0
Sumy=0
Meanx=0
Meany=0
Sumdiffx2=0
Sumdiffy2=0
Sumdiffz2=0
Sumdistz=0
SDx=0
SDy=0
Sdz=0
n=0
if [ -f $Datapath/$Datafile.csv ]
  then
while read x y 					# read x,y from Datafile
  do								# loop
    n=$(($n+1))					# count data points
    echo "$x	$y"
    Sumx=$(echo "scale=4; $Sumx+$x" | bc)
    Sumy=$(echo "scale=4; $Sumy+$y" | bc)
  done < $Datapath/$Datafile.csv
# exit
Meanx=$(echo "scale=4; $Sumx/$n" | bc)	# calculate mean x,y == SUMx/n, SUMy/n
Meany=$(echo "scale=4; $Sumy/$n" | bc)
echo "Mean x =" $Meanx
echo "Mean y =" $Meany
#exit
while read x y 					# read x,y
  do								# loop 2
    Diffx2=$(echo "scale=4; ($x-($Meanx))^2" | bc -l)
    Diffy2=$(echo "scale=4; ($y-($Meany))^2" | bc -l)
    Diffz2=$(echo "scale=4; ($Diffx2+$Diffy2)" | bc -l)
    Distz=$(echo "scale=4; sqrt($Diffx2+$Diffy2)" | bc -l)
 #   echo $Diffx2 $Diffy2
    Sumdiffx2=$(echo "scale=4; $Sumdiffx2+$Diffx2" | bc -l)
    Sumdiffy2=$(echo "scale=4; $Sumdiffy2+$Diffy2" | bc -l) 
   Sumdiffz2=$(echo "scale=4; $Sumdiffz2+$Diffz2" | bc -l)
    Sumdistz=$(echo "scale=4; $Sumdistz+$Distz" | bc -l)
    done < $Datapath/$Datafile.csv
SDx=$(echo "scale=2; sqrt($Sumdiffx2/$n)" | bc -l)
SDy=$(echo "scale=2; sqrt($Sumdiffy2/$n)" | bc -l)
SDz=$(echo "scale=2; sqrt($Sumdiffz2/$n)" | bc -l)
DistMean=$(echo "scale=2; ($Sumdistz/$n)" | bc -l)
echo "Standard deviation of x =" $SDx
echo "Standard deviation of y =" $SDy
echo "" >> $Outfile
SDsum=$(echo "scale=2; $SDx+$SDy" | bc -l)
# ###########
# n=0
# MaxSpread=0
# while read x y 					# read first x,y from Datafile
#   do								# loop
#     n=$(($n+1))					# count data points
#     x["$n"]=$x
#     y["$n"]=$y
#   done < $Datapath/$Datafile.csv
# i=1
# while [ $i -lt $n ]
#   do
#   j=$(($i+1))
#   while [ $j -lt $(($n+1)) ]
#   do
#   Diffx2=$(echo "scale=4; ((${x[$i]})-(${x[$j]}))^2" | bc -l)
#   Diffy2=$(echo "scale=4; ((${y[$i]})-(${y[$j]}))^2" | bc -l)
#   Distance=$(echo "scale=2; sqrt($Diffx2+$Diffy2)" | bc -l)
#   j=$(($j+1))
#     echo "Distance=	$Distance MaxSpread= $MaxSpread"
#  # echo The difference is $(echo "$Distance-$MaxSpread" | bc -l)
#   test_cond=`echo "$Distance > $MaxSpread" | bc`
#  # echo $test_cond
#   
#   if [ $test_cond == 1 ]; then MaxSpread=$(echo "scale=2; $Distance-0.00" | bc -l)
#   fi
# 
#   done
#     i=$(($i+1))
# done
# ############
if [ $n = 0 ] 
then echo "Bad Data"
else
echo "*************************************" >> $Outfile
echo "*         Data for $Datafile         " >> $Outfile
echo "*     --------------------------    *" >> $Outfile
echo "*                                   *" >> $Outfile
echo "*   Mean value of x = $Meanx         " >> $Outfile
echo "*   Mean value of y = $Meany           " >> $Outfile
echo "*                                   *" >> $Outfile
echo "*   Ave. distance from center = $DistMean           " >> $Outfile
echo "*                                   *" >> $Outfile
echo "*   Standard deviation of x = $SDx   *" >> $Outfile
echo "*   Standard deviation of y = $SDy   *"  >> $Outfile
echo "*   Standard deviation of z = $SDz   " >> $Outfile
echo "n =" $n
echo "*   n = $n               Sum = $SDsum  *" >> $Outfile
echo "*                                   *" >> $Outfile
echo "*************************************" >> $Outfile
echo "" >> $Outfile
cat $Outfile
#Load=`echo $Datafile | sed 's/[A-Za-z]*//g'`
#echo "$Load, $SDsum" >> $Datapath/GraphData.$Series
echo ""
fi
else echo "Not a file. Try again, please!"
fi
echo " Would you like to continue? y/n"
read Cont
done
#echo " Would you like to see the graph? y/n:"
#read query
#[ $query = "y" ] && quickplot $Datapath/GraphData.$Series &
# calculate differences x,y; square them; sum them == 
# calculate standard deviation x,y == SQRT (SUMSQUARES/N)Q
# output data

# Arithmetic
# n=$((n+1))  == n=$(($n+1)) == let n=$n+1 == (($n++))
# echo "scale=3; sqrt(x)" | bc -l
# 	      variable=$(echo "OPTIONS; OPERATIONS" | bc)

