use strict;
#use warnings;
my @blast_value=(); #�˵���web-blast����

my @database01_value=(); #�˵������ݿ�����1	  
my @database02_value=(); #�˵������ݿ�����2	

my @database01_name=(); #���� ���ݿ�����1	<!-- blastn, megablast, discomegablast, tblastn, tblastx -->
my @database02_name=(); #���� ���ݿ�����2	<!-- blastp,psiblast,phibalst or blastx -->

my @result_table=(); #�������ͷ

&init_parms();#��ʼ������

my $file_name=&load_input_menu(); 
my $blast_id=&load_blast_menu();
my $program_id=&load_database_menu;  
my $output=&load_output_menu;
my $rank=&load_rank_menu;

#�ж�����:blast database
 if ($blast_id =~ /[012]/ and $program_id>17){
	print "input error 1";
	exit;
 }elsif($blast_id =~ /[34]/ and $program_id>7){
 	print "input error 2";
	exit;
 }
 
#�����û������blast_id�Լ����ݿ��������ñ��е�blast��dadabase	
my $database_name=($blast_id =~ /[012]/?$database01_name[$program_id]:$database02_name[$program_id]);
my $blast_name=$blast_value[$blast_id];

#��ӡ�ύ��Ϣ
print "your choose database\t$database_name\n";
print "your choose blast\t$blast_name\n";
print "your set rank\t$rank\n\n\n";
print "Submiting now..............\n\n";

#������ͷ
open(OUTPUT, ">$output") or die "output file error";
print OUTPUT "$_\t" foreach(@result_table);
print OUTPUT "\n";

#�½������
use LWP;	
my $ua = LWP::UserAgent->new;

#�ݽ�����վ,����ȡ�Զ�������
&main();

close OUTPUT;



#�����
sub main(){
	
	#1. ��ȡ�ļ�
	my $seqs_name_arr_ref = &get_seqs_name($file_name);
	my @seqs_name = @$seqs_name_arr_ref;
	
	#2. �ϴ����У���ȡRID
	my $rid = &submit_file($blast_id, $database_name);

	#3. ѭ��1����Ԫ-����
	foreach my$query_index(0..@seqs_name-1){
		my $url = "https://blast.ncbi.nlm.nih.gov/Blast.cgi?CMD=Get&RID=$rid&QUERY_INDEX=$query_index";
		my $web_content = $ua->get($url)->content; 	
		if ($web_content =~ /^\s*?\<p class=\"info\"\>No significant similarity found$/im){
			#    <p class="info">No significant similarity found
			print "\n\nNo significant similarity found for Seq:  $seqs_name[$query_index]\n\n";
			next;
		}
		$web_content =~ s/\n//g;
		
		#4. �����ҳ���
		my $trs_arr_ref = &split_seq_results($web_content);
		
		#5. ��ȡ����
		&get_rank($rank, $seqs_name[$query_index],$query_index, $trs_arr_ref);
#		last;
	}
}
=head
	���ܣ��ݽ������ļ���ncbi���ȴ�ˢ�½�������ȡrid
	
=cut
sub submit_file(){
	
	 #����blast_id����program
	my ($program, $database) = @_;
	if ($program == 0){#megablast
		$program = "blastn&MEGABLAST=on";
	}elsif ($program == 1){#tblastn
		$program = "tblastn";
	}elsif ($program == 2){#tblastx
		$program = "tblastx";
	}elsif ($program == 3){#blastp
		$program = "blastp&plain=on";
	}elsif ($program == 4){#blastx
		$program = "blastx";
	}  
	my $url = "https://blast.ncbi.nlm.nih.gov/Blast.cgi?";		
	my $submit_url=$url."PROGRAM=$program&PAGE_TYPE=BlastSearch&LINK_LOC=blasthome";
	my $res=$ua->post(
		$submit_url,
		['QUERYFILE'=>[$file_name],'DATABASE'=>$database,'CMD'=>'Put',],
		'Content-Type'=>"form-data"); 
	
	my ($rid) = $res->content =~ /^    RID = (.*$)/m;
	
	my $res_web = $url."CMD=Get&RID=$rid";
	while ("true"){
			my $res= $ua->get($res_web);#��ȡĿ��ҳ��	
			$res = $res->content;
			#�ж��Ƿ�ˢ�����
			if($res =~ /^\s*?Status=WAITING$/m){#�����ƥ�䵽
				print "Querying...This WEB-BLAST-INFO will be automatically updated in 15 seconds","\n\n";
				sleep 10;#���20��
						
			}
			elsif($res =~ /^\s*?Status=READY$/m){
				print "Query WEB-BLAST-INFO Success.";
				return $rid;
				
			}else{
				print "Query error, Please check your Network or BLAST Settings!";
				exit;	

			}			
		
		}	
}
=head
	���ܣ����������еĽ���������tbody��
	����������飺����Ϊ0-99������100�����飨�У�tr����
			�����飺����Ϊ0-7������8���ַ������У�td����
	��������ҳ����,Ҫ��ȡ��������Ŀ		
    ���أ���������			
=cut
sub split_seq_results(){
		#�������
		my($web_content) = @_;
	
		my ($tbody) = $web_content=~/(\<tbody\>.*\<\/tbody\>)/i;		
		my @trs = ();
		my $ind = 0;
		 
		 #��ȡtr��ǩ������Ԫ��,�ܹ�100��Ԫ��
		while($tbody =~ /(\<tr.*?\>.*?\<\/tr\>)/ig){#gΪȫ��ƥ�䣬һ��Ҫ��
			#����td��ǩ���ܹ�8��
		  	my $td=$1;				
			my @tds = ();			
			$trs[$ind++] = \@tds;#���tds����ind=0ʱ�����8����������td
			
			while($td =~ /\<td[\s|\>](.*?)\<\/td\>/ig ){
				
				push @tds,$1;
			}
			#����td
			# 0	Id
			# 1 Description
			# 2-6	Max score	Total score	Query coverage	E value	Ident	
			# 7	Accession
			($tds[0]) = $tds[0] =~ /value=\"(.*?)\"/i;#ע��1�����Լ�,2��ӱ�־��,
			
			($tds[1]) = $tds[1] =~ /\<a.*?\>(.*?)\<\/a\>/i;#Description
			
			foreach(2..6){
				($tds[$_]) = $tds[$_] =~ /\>(.*)/;
			}			
			
			($tds[7]) = $tds[7] =~ /\<a.*?>(.*?)\<\/a\>/i;#Accession
			
#			print "$_\n" foreach(@tds);
#			last;			
			
		 }
		 return (\@trs);
	
}
=head
	���ܣ���ȡָ�������Ľ���������ݽ���е�id�������飬����ȡtaxon
	�����
	������$rank-����
	���أ�
=cut	
sub get_rank(){	 
	my ($rank, $seq_name, $query_index, $trs_arr_ref) = @_;
	
		my @trs = @$trs_arr_ref;		
		 # ���������ȡ�ض���Ŀ������
		foreach my $ind(0..$rank-1){
			# print $trs[$ind],"\n";#��ȡrank������
			# ��ȡǶ����������
			my $ref = $trs[$ind];
			
			my @tds = @$ref;
			my $id = $tds[0];
			print "\n\n\nNow begining query:...\nSeq name: $seq_name, Rank: ",$ind+1,"\n\n\n";
			my $url = "https://www.ncbi.nlm.nih.gov/sviewer/viewer.cgi?id=$id";
			my $taxon="";
			my $res = $ua->get(
					$url,
					':content_cb'     => sub{
						#print$_[0];
						last if(($taxon)=$_[0] =~/\/db_xref\=\"taxon:(.*?)\"/i);},
					':read_size_hint' => 16 * 1024,
				);
				
			print "id: $id\n\n\nGet Taxon success, now downloading it's Taxonomy, Taxon: $taxon\n\n\n";			
			my $organism = get_specials($taxon);
			#��ӡ�����Ϣ
			print "Query Seq_name: $seq_name, Rank: ",$ind+1," success.\nNow showing and saving it's Taxonomy, Taxon and Score Table\n\n\n";			
			print "$result_table[$_+1]:\t$tds[$_]\n" foreach(0..7);
			print "$result_table[9]:\t$taxon\n";
			print "Taxonomy:\t$organism";
			
			#�����ļ�
			print OUTPUT "$seq_name\t";
			print OUTPUT "$_\t" foreach(@tds);
			print OUTPUT "$taxon\t";
			print OUTPUT "$organism\n";
			
}			
	}	
	
=head
	���ܣ���ȡid��Ӧ��������Ϣ��
	����������ļ�������taxon
	������������rank��id�� �ļ�����:$gbs_dir
	���أ�taxon
=cut
sub get_taxon(){
	my ($id,$rank) = @_;
	
	my $url = "https://www.ncbi.nlm.nih.gov/sviewer/viewer.cgi?id=$id";
	my $res = $ua->get($url)->content; 
	my ($taxon) = $res=~/\/db_xref\=\"taxon:(.*?)\"/i;
	#������ҳ��Ϣ
#	print $taxon;
	#������ҳ����
	# open(OUT, ">$dir/rank_$rank+id_$id.gb");
	# select OUT;
	# print $res;
	# close OUT;   
	
	return $taxon;
}			
		
=head
	���ܣ���ȡ���ַ���
	������taxon
=cut	
sub get_specials(){
	use LWP::UserAgent; 	
	my ($taxon) = @_;																			
	my $tax_url="https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi";  #���÷����������ҳurl	
	my $res=LWP::UserAgent->new->post($tax_url,['name'=>$taxon]);  		#��Ŀ��ҳ�淢��post����
	my @web = split( /\r?\n/, $res->content);			#��Դ�����Իس����ѳɶ���
	
	my @bio_info =qw(superkingdom phylum class order family genus species);	
	
	my ($target_line,$organism)="";
	foreach my $line(@web){
		my $i = 0;
		foreach(@bio_info){#���ƥ��ɹ�,��ƥ�����+1
			if ($line =~ /($_)/){
				$i++;
				if ($i >=2){#������ֵ�������2��,���˳���ǰ
					$target_line = $line;
					last;						
					}							
				} 
			}
		last if($target_line);#�����ҵ�Ŀ���м��˳�	
		}
		#��ȡ����
	foreach(0...6){		
		if($target_line =~ /(\=\"$bio_info[$_]\">)([^<>]*)(<\/)/){
			$organism .= "$2\t";	
		}else{
			$organism .= "\t";
			}			
	}
	return $organism;
}
#����������
#�����ϴ����ļ�����ȡ������������������
=head
	���ܣ������ϴ���fasta�ļ�
	��������飺����������ţ�0-��������Ŀ-1��
				����Ϊ������
	������fasta��ʽ�ļ���			
	���أ���������
=cut
sub get_seqs_name(){
	my ($in_file) = @_;
	my @seqs_name=();	#���������
	open(FASTA,$in_file)or die "file error";
	foreach(<FASTA>){
		if($_ =~ /^>([^\s]*)\s/){
			push @seqs_name,$1;#�����������ȡ��taxon_id����Ӧ

			}
		}
	close FASTA ;
	return \@seqs_name;
	}
	
	
	
#��ʼ������
sub init_parms(){
	
	&load_blast_parms();#����blast����	
	&load_database_parms();#����˵��Ĳ���
	
	&load_table_parms();#��������ݵĲ���		
	&load_table_header();#�������ļ��ı�ͷ
}
###################################  DATA  ############################
#����blast����	
sub load_blast_parms {
	$blast_value[0]="Blastn  (nucleotide - nucleotide BLAST)";#megaBlast;
	$blast_value[1]="Tblastn (translated nucleotide - protein BLAST) ";#tblastn
	$blast_value[2]="Tblastx (translated nucleotide - translated nucleotide BLAST)";#tblastx
	$blast_value[3]="Blastp  (protein-protein BLAST)";#blastp
	$blast_value[4]="Blastx  (protein - translated nucleotide BLAST)";	#blastx	
	
}
#����˵��Ĳ���
sub load_database_parms {
	
	$database01_value[0]="Human genomic plus transcript (Human G+T)";
	$database01_value[1]="Mouse genomic plus transcript (Mouse G+T)";
	$database01_value[2]="Nucleotide collection (nr/nt)";
	$database01_value[3]="16S ribosomal RNA sequences (Bacteria and Archaea)";
	$database01_value[4]="Reference RNA sequences (refseq_rna)";
	$database01_value[5]="RefSeq Representative genomes (refseq_representative_genomes)";
	$database01_value[6]="RefSeq Genome Database (refseq_genomes)";
	$database01_value[7]="Whole-genome shotgun contigs (wgs)";
	$database01_value[8]="Expressed sequence tags (est)";
	$database01_value[9]="Sequence Read Archive (SRA) ";
	$database01_value[10]="Transcriptome Shotgun Assembly (TSA)";
	$database01_value[11]="High throughput genomic sequences (HTGS)";
	$database01_value[12]="Patent sequences(pat)";
	$database01_value[13]="Protein Data Bank (pdb)";
	$database01_value[14]="Reference genomic sequences (refseq_genomic)";
	$database01_value[15]="Human RefSeqGene sequences(RefSeq_Gene)";
	$database01_value[16]="Genomic survey sequences (gss)";
	$database01_value[17]="Sequence tagged sites (dbsts)";	
	
	$database02_value[0]="Non-redundant protein sequences (nr)";
	$database02_value[1]="Reference proteins (refseq_protein)";
	$database02_value[2]="Model Organisms (landmark)";
	$database02_value[3]="UniProtKB/Swiss-Prot(swissprot)";
	$database02_value[4]="Patented protein sequences(pat)";
	$database02_value[5]="Protein Data Bank proteins(pdb)";
	$database02_value[6]="Metagenomic proteins(env_nr)";
	$database02_value[7]="Transcriptome Shotgun Assembly proteins (tsa_nr)";		
}
#��������ݵĲ���
sub load_table_parms {
	
	#<!-- blastn, megablast, discomegablast, tblastn, tblastx -->  
	$database01_name[0]="GPIPE/9606/current/all_top_level GPIPE/9606/current/rna";
	$database01_name[1]="GPIPE/10090/current/all_top_level GPIPE/10090/current/rna";
	$database01_name[2]="nr";#Ĭ��
	$database01_name[3]="rRNA_typestrains/prokaryotic_16S_ribosomal_RNA";
	$database01_name[4]="refseq_rna";
	$database01_name[5]="refseq_representative_genomes";
	$database01_name[6]="refseq_genomes";
	$database01_name[7]="Whole_Genome_Shotgun_contigs";
	$database01_name[8]="est";
	$database01_name[9]="sra";
	$database01_name[10]="tsa_nt";
	$database01_name[11]="htgs";
	$database01_name[12]="pat";
	$database01_name[13]="pdb";
	$database01_name[14]="refseq_genomic";
	$database01_name[15]="genomic/9606/RefSeqGene";
	$database01_name[16]="gss";
	$database01_name[17]="dbsts";	
	
	#<!-- blastp,psiblast,phibalst or blastx -->	
	$database02_name[0]="nr";#Ĭ��
	$database02_name[1]="refseq_protein";
	$database02_name[2]="SMARTBLAST/landmark";
	$database02_name[3]="swissprot";
	$database02_name[4]="pat";
	$database02_name[5]="pdb";
	$database02_name[6]="env_nr";
	$database02_name[7]="tsa_nr";	
}
#��������ͷ
sub load_table_header {
	#������ͷ-Ҫ��ȡ��������Ϣ
	@result_table =qw(Seq_name Gi Description Max_score 
		Total_score Query_cover E_value Ident Accession
		Taxon 
		Superkingdom Phylum Class Order Family Genus Species);
}	


#���˵�
#���ܣ���ʾ�û�����input��file	
sub load_input_menu {

	print "\n\n\n".
		"*************************************************
		***********   FASTA Seq Identify   **************
		*************************************************".
		"\n\n\n".
		"[STEP]\n".
		"	1. Sequence Input From Disc\n".
		"	2. Set WEB-BLAST \n".
		"	3. Set Database for BLAST\n".
		"	4. Set Rank for BLAST Result Save\n".
		"	5. Set Output File\n\n\n";	
		
	#1.��ʾ�û������ļ�����
	print "Now, Please Input Your FASTA File Name:";
	
	my $file_name=<STDIN>;chomp $file_name;	
	return $file_name;			
}


#blast�˵�
sub load_blast_menu {
	#2.���û����ò���1���㷨��
	#print "filename\t$file_name";
	print "\n\n\n*************Please Choose Web BLAST*************\n\n\n";
	for (my$i=0;$i<@blast_value;$i++){
		print "\t$i. $blast_value[$i]\n";
	}
	print "\n\n\nYour choose: ";

	return <STDIN>;	
}

#database�˵�
sub load_database_menu {
	#3.���û����ò���2�����ݿ⡣���㷨�����ݿ���󶨣�����������ϵ�� 
	print "*************Please Choose BLAST DATABASE*************\n\n\n";
	if ($blast_id =~ /[012]/){
		for (my$i=0;$i<@database01_value;$i++){
			print "\t$i. $database01_value[$i]\n";
		}
	}elsif($blast_id =~ /[34]/){
		for (my$i=0;$i<@database02_value;$i++){
			print "\t$i. $database02_value[$i]\n";
		}
	}else{
		print "input error";
		exit;
	}
	print "\n\n\nYour choose: ";
	
	return <STDIN>;		
}
#rank�˵�
sub load_rank_menu {
	
	print "*************Please Set Rank [1..100] For Blast*************\n\n";
	print "Rank : ";
	
	return <STDIN>;	
}
#output�˵�
sub load_output_menu {
	
	print "*************Please Set Output File For Saving Result*************\n\n\n"; 
	
	return <STDIN>;	
}	