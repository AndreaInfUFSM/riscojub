#!/bin/bash
##
## Analisa relatorio SIE/UFSM para detectar alunos do Curso de Ciencia da Computacao em risco de
## jubilamento por decurso de prazo de integralizacao curricular.
## A saida é formatada para facilitar o envio de alertas aos alunos em risco
##
## Autores: Benhur Stein, Andrea Charao
## Ultima revisao: mar/2014
## Bash version: 4.2.45(1)-release
## 

if [ $# -ne 1 ] ; then
    echo "Uso: $0 <rel-sie-1-1-5-20-07-historico-simplificado.csv>"
    echo "Exemplo: bash $0 1-1-5-20-07-historico-escolar-simplificado-por-curso-alunos-regulares-2006-em-diante-com-trancamentos.csv"
    exit 1
fi

# Entrada: relatorio do SIE com historico dos alunos
# Emitir relatorio em xls e converter para CSV (delimitacao de campos por virgula).
# Quando alterar e salvar o CSV, nao delimitar texto por aspas.
# Obs.1: Para importar esse CSV no google spreadsheets, salvar como encoding ISO-8859-1 e nao UTF8
# Obs.2: Versão 2013 do histórico incluía trancamentos totais mas também disciplinas de outros cursos que nao contam para integralização.
# Obs.3: Versão 2014 do histórico não inclui trancamentos totais nem disciplinas de outros cursos. Os trancamentos totais podem ser obtidos em relatório separado, que precisa ser emitido para cada ano/semestre.

relatorio=$1

# Carga horaria total do curso (excluindo acgs)
# chtotal = 2160obr + 600dcg + 180tg = 2940
chtotal=2940

# Ano / semestre atuais
# Supoe-se que o relatorio so tenha dados ate o semestre anterior a esse
anoatual=2014
sematual=2

# Limite da diferenca (media_cursados-med_futura) para alunos em risco
# Para considerar todos alunos, colocar limite bem alto, maior que carga horaria media por semestre
limite_risco=0

# Listar somente alunos ingressantes ATE este ano (desconsidera alunos recem ingressantes)
# Deixar vazio para listar todos alunos em risco
filtro_ano_ingr=2012

# Arquivos intermediarios e saida
tmpAprov=/tmp/.xx1
tmpTranc=/tmp/.xx2
tmpAluno=/tmp/.xx3
arqRisco=emrisco.csv

# Calcula numero maximo de semestres para integralizacao curricular (maxsem) 
# a partir do ano de ingresso
# Argumento $1 = ano de ingresso
function calcMaxSem {
  if [ $1 -gt 2010 ]; then
    maxsem=12
  else
    maxsem=16
  fi
}


# Filtra relatorio (CSV com campos de texto separados COM aspas)
#grep ",\"Aprovado \|,\"Dispensado \|,\"Aproveitamento" $relatorio | while read a; do echo $a,A; done > $tmpAprov
# Filtra relatorio (CSV com campos de texto separados SEM aspas)
grep ",Aprovado \|,Dispensado \|,Aproveitamento" $relatorio | grep -v ",Disciplinas de Outros Cursos" | grep -v ",Disciplinas de Currículos Anteriores" | while read a; do echo $a,A; done > $tmpAprov
grep "Trancamento Total" $relatorio | while read a; do echo $a,T; done > $tmpTranc

# Inicializa arquivos
echo  "matr,nome,prenom,sexo,email,ingr,maxsem,tranca,sem_cursados,ch_cursada,med,medfut,dif" > $arqRisco
echo -n > $tmpAluno

# 1==> Seleciona campos do relatorio pre-processado
# 2 = NOME_PESSOA
# 4 = MATR_ALUNO
# 9 = ANO
# 15 = SEMESTRE
# 20 = TOTAL_CARGA_HORARIA
# 22 = ANO_INGRESSO
# 25 = SEXO (para personalizar email)
# 27 = situacao (campo adicionado: A | T)
# 2==> Troca ordem dos campos, colocando nome para o final
# 3==> Ordena por: nome, sit, ano, sem (na nova ordem dos campos selecionados)
# 4==> Inclui uma linha no final para deteccao de novo aluno na lista

(cat $tmpAprov $tmpTranc | iconv -f ISO_8859-1 -t UTF8 |sed -e 's/. Semestre//' | cut -d, -f2,4,9,15,20,22,25,27 | sed -e 's/\([^,]*\),\(.*\)/\2,\1/' | sort -t, -s -k8,8 -k7,7 -k2,2 -k3,3|tr , ' ';echo a b c d e f g h) | while read matr ano sem ch ingr sexo sit nome
do
  # Linha nao precisa ser processada
  if [ x$filtro_ano_ingr != x ] && [ $ingr != e ] && [ $ingr -gt $filtro_ano_ingr ]; then
    continue
  fi
  # Registra trancamento para o aluno
  if [ x$sit = xT ]; then
    tranca=$[$tranca+1]
    echo $ano.$sem TRT >> $tmpAluno
    continue
  fi
  # Registra carga horaria total do semestre para o aluno
  if [ x$SA != x$ano.$sem -o x$M != x$matr ]; then
    if [ x$SA != x ]; then
      echo $SA $T1CH $M >> $tmpAluno
      TNS=$[$TNS+1] # incrementa numero de semestres cursados
    fi
    SA=$ano.$sem
    T1CH=0
  fi

  # Terminou de processar todas linhas de um aluno, então
  # faz os cálculos e mostra/grava os dados
  if [ x$M != x$matr ]; then
    if [ x$M != x ]; then

      # Calcula semestres que faltam para encerrar o prazo, incluindo semestre atual e descontando
      # trancamentos. Exemplo: para aluno ingressante em 2006, em 2013/1 faltarão 2 semestres, 
      # em 2013/2 faltará 1 semestre
      calcMaxSem $INGR
      falta=$[$maxsem+$tranca-(($anoatual-$INGR)*2+$sematual-1)]
      cursados=$[($anoatual-$INGR)*2+$sematual-1-$tranca]

      # Calcula med_cursada = ch_cursada / numero de semestres cursados
      med_cursada=$[$TCH/$cursados]

      # Calcula dif = (med_cursada) - (carga horaria que falta / numero de semestres que faltam)
      if [ $falta -gt 0 ]; then
        medfut=$[($chtotal-$TCH)/$falta]
        dif=$[$med_cursada-$medfut-1]
      else
        # Aluno com prazo expirado
        medfut=$med_cursada
	dif=$[$limite_risco-1] 
      fi
      
      # Mostra dados de aluno em risco
      if [ $dif -lt $limite_risco ]; then
        echo -n $NOME $M $INGR maxsem=$maxsem ch_cursada=$TCH sem_cursados=$cursados med=$med_cursada falta=$falta tr=$tranca
        if [ $falta -gt 0 ]; then
          echo "" medfut=$medfut dif=$dif
        else
          echo "" PRAZO EXPIRADO
        fi
        # Mostra resumo dos semestres cursados pelo aluno
        cat $tmpAluno | sort
        # Extrai prenome do aluno
        # Ver conversoes bash 4 em http://stackoverflow.com/questions/2264428/
        prenom=`echo $NOME | cut -d' ' -f 1`
        prenom=${prenom,,}
        prenom=${prenom^}
        #prenom=${prenom[@]^} # nao funciona em bash 4.3.11(1)-release ?!
        # Registra aluno em risco
	echo $M,$NOME,$prenom,$SEXO,,$INGR,$maxsem,$tranca,$cursados,$TCH,$med_cursada,$medfut,$dif >> $arqRisco
      fi
    fi
    M=$matr
    NOME=$nome
    INGR=$ingr
    if [ $sexo == 'M' ]; then SEXO='o'; else SEXO='a'; fi
    TCH=0
    TNS=0
    tranca=0
    echo -n > $tmpAluno
  fi
  T1CH=$[$T1CH+$ch]
  TCH=$[$TCH+$ch]
done 

# Totais desconsiderando a primeira linha, que contem cabecalho
echo "Total de alunos no relatorio: " `cat $relatorio |cut -f 1 -d ,|sort -n |uniq|tail -n +2 |wc -l`
echo "Total de alunos em risco ate $filtro_ano_ingr: " `tail -n +2 $arqRisco |wc -l`


#----------------------------------------------------------------------------------------------------
# Anotacoes preliminares de pre-processamento de relatorios do SIE
#----------------------------------------------------------------------------------------------------
#-f 14 -d ','
#DESCR_SITUACAO (-f 14)
#Aprovado com nota
#Aprovado sem nota
#Aproveitamento
#Dispensado com nota
#Dispensado sem  nota
#Incompleto
#Interc�mbio
#Matr�cula
#Reprovado com nota
#Reprovado por Frequ�ncia
#Trancamento parcial
#Trancamento Total

#andrea@vostro:~/coord-bcc/jubilamento$ head -1 1-1-5-20-07-historico-escolar-simplificado-por-curso-alunos-regulares-2005-em-diante.csv 
#ID_PESSOA,NOME_PESSOA,ID_ALUNO,MATR_ALUNO,NUM_VERSAO,NOME_CURSO,COD_CURSO,ID_VERSAO_CURSO,ANO,COD_ATIV_CURRIC,NOME_ATIV_CURRIC,CREDITOS,MEDIA_FINAL,DESCR_SITUACAO,PERIODO,ID_CURSO_ALUNO,SITUACAO_ITEM,CH_TEORICA,CH_PRATICA,TOTAL_CARGA_HORARIA,FORMA_INGRESSO,ANO_INGRESSO,FORMA_EVAS�O,ANO_EVAS�O,SEXO

#Filtrar, mantendo apenas: 
#aprovado com nota, aprovado sem nota, aproveitamento, dispensado,trancamento total

#2 NOME_PESSOA
#4 MATR_ALUNO
#9 ANO
#14 DESCR_SITUACAO
#15 PERIODO
#20 TOTAL_CARGA_HORARIA
#22 ANO_INGRESSO


#andrea@vostro:~/coord-bcc/jubilamento$ head -1 1-1-5-08-29-integralizacao-curricular-alunos-regulares-por-curso-2013a.csv 
#ID_ATIV_CURRIC,COD_DISCIPLINA,NOME_DISCIPLINA,PERIODO_IDEAL,CH_TOTAL,PERIODO,ANO,SITUACAO_DISC,DESCR_ESTRUTURA,COD_CURSO,NOME_UNIDADE,NUM_VERSAO,MATR_ALUNO,NOME_PESSOA,CREDITOS,CARGA_CURSO,CH_EXIGIDA,IND_VENCIDA,ID_VERSAO_CURSO,ID_ESTRUTURA_CUR,ID_CURSO_ALUNO,ANO_INGRESSO,PERIODO_INGRE_ITEM,CLASS_ATIV_ITEM

#5 CH_TOTAL
#6 PERIODO
#7 ANO
#13 MATR_ALUNO
#22 ANO_INGRESSO


#(fgrep ,Vencido $relatorio|fgrep -v "Atividades Complementares"|sed -e 's/. Semestre//' |cut -d, -f5,6,7,13,22|sort -t, -s -k4,4 -k3,3 -k2,2|tr , ' ';echo a b c d e)|while read ch sem ano matr ingr

#2 NOME_PESSOA
#4 MATR_ALUNO
#9 ANO
#14 DESCR_SITUACAO
#15 PERIODO
#20 TOTAL_CARGA_HORARIA
#22 ANO_INGRESSO
#24 SEXO
#27 A|T

#(grep ",Aprovado \|,Dispensado \|,Aproveitamento\|Trancamento Total" 1-1-5-20-07-historico-escolar-simplificado-por-curso-alunos-regulares-2005-em-diante.csv|sed -e 's/. Semestre//'| cut -d, -f2,4,9,14,15,20,22 | sort -t, -s -k1,1 -k3,3 -k5,5|tr , ' ';echo a b c d e f g)|while read nome matr ano sit sem ch ingr

