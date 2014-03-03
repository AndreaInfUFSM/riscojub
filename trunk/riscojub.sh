(fgrep ,Vencido 1-1-5-08-29-integralizacao-curricular-alunos-regulares-por-curso-2013a.csv|fgrep -v "Atividades Complementares"|sed -e 's/. Semestre//' |cut -d, -f5,6,7,13,22|sort -t, -s -k4,4 -k3,3 -k2,2|tr , ' ';echo a b c d e)|while read ch sem ano matr ingr
do
  if [ x$SA != x$ano.$sem -o x$M != x$matr ]; then
    if [ x$SA != x ]; then
      echo $SA $T1CH $M
      TNS=$[$TNS+1]
    fi
    SA=$ano.$sem
    T1CH=0
  fi
  if [ x$M != x$matr ]; then
    if [ x$M != x ]; then
      falta=$[16-(2013-$INGR)*2]
#     falta=$[16-$TNS]
      echo -n $TCH $TNS $M $INGR med=$[$TCH/$TNS] falta=$falta
      if [ $falta -gt 0 ]; then
        echo "" medfut=$[(2940-$TCH)/$falta] dif=$[$TCH/$TNS-(2940-$TCH)/$falta]
      else
        echo "" PRAZO EXPIRADO
      fi
    fi
    M=$matr
    INGR=$ingr
    TCH=0
    TNS=0
  fi
  T1CH=$[$T1CH+$ch]
  TCH=$[$TCH+$ch]
done 

