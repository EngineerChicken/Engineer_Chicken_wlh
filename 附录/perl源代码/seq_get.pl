use strict;
#use warnings;
my @blast_value=(); #菜单：web-blast种类

my @database01_value=(); #菜单：数据库种类1	  
my @database02_value=(); #菜单：数据库种类2	

my @database01_name=(); #表单： 数据库种类1	<!-- blastn, megablast, discomegablast, tblastn, tblastx -->
my @database02_name=(); #表单： 数据库种类2	<!-- blastp,psiblast,phibalst or blastx -->

my @result_table=(); #结果：表头

&init_parms();#初始化参数

my $file_name=&load_input_menu(); 
my $blast_id=&load_blast_menu();
my $program_id=&load_database_menu;  
my $output=&load_output_menu;
my $rank=&load_rank_menu;

#判断输入:blast database
 if ($blast_id =~ /[012]/ and $program_id>17){
	print "input error 1";
	exit;
 }elsif($blast_id =~ /[34]/ and $program_id>7){
 	print "input error 2";
	exit;
 }
 
#根据用户输入的blast_id以及数据库索引设置表单中的blast和dadabase	
my $database_name=($blast_id =~ /[012]/?$database01_name[$program_id]:$database02_name[$program_id]);
my $blast_name=$blast_value[$blast_id];

#打印提交信息
print "your choose database\t$database_name\n";
print "your choose blast\t$blast_name\n";
print "your set rank\t$rank\n\n\n";
print "Submiting now..............\n\n";

#建立表头
open(OUTPUT, ">$output") or die "output file error";
print OUTPUT "$_\t" foreach(@result_table);
print OUTPUT "\n";

#新建浏览器
use LWP;	
my $ua = LWP::UserAgent->new;

#递交到网站,并获取自动保存结果
&main();

close OUTPUT;



#主入口
sub main(){
	
	#1. 读取文件
	my $seqs_name_arr_ref = &get_seqs_name($file_name);
	my @seqs_name = @$seqs_name_arr_ref;
	
	#2. 上传序列，获取RID
	my $rid = &submit_file($blast_id, $database_name);

	#3. 循环1：单元-序列
	foreach my$query_index(0..@seqs_name-1){
		my $url = "https://blast.ncbi.nlm.nih.gov/Blast.cgi?CMD=Get&RID=$rid&QUERY_INDEX=$query_index";
		my $web_content = $ua->get($url)->content; 	
		if ($web_content =~ /^\s*?\<p class=\"info\"\>No significant similarity found$/im){
			#    <p class="info">No significant similarity found
			print "\n\nNo significant similarity found for Seq:  $seqs_name[$query_index]\n\n";
			next;
		}
		$web_content =~ s/\n//g;
		
		#4. 拆分网页结果
		my $trs_arr_ref = &split_seq_results($web_content);
		
		#5. 获取排名
		&get_rank($rank, $seqs_name[$query_index],$query_index, $trs_arr_ref);
#		last;
	}
}
=head
	功能：递交序列文件到ncbi，等待刷新结束，获取rid
	
=cut
sub submit_file(){
	
	 #根据blast_id设置program
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
			my $res= $ua->get($res_web);#获取目的页面	
			$res = $res->content;
			#判断是否刷新完毕
			if($res =~ /^\s*?Status=WAITING$/m){#如果能匹配到
				print "Querying...This WEB-BLAST-INFO will be automatically updated in 15 seconds","\n\n";
				sleep 10;#间隔20秒
						
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
	功能：处理单个序列的结果集（表格，tbody）
	结果：父数组：索引为0-99，包含100个数组（行，tr）。
			子数组：索引为0-7，包含8个字符串（列，td·）
	参数：网页内容,要获取的排名数目		
    返回：数组引用			
=cut
sub split_seq_results(){
		#传入参数
		my($web_content) = @_;
	
		my ($tbody) = $web_content=~/(\<tbody\>.*\<\/tbody\>)/i;		
		my @trs = ();
		my $ind = 0;
		 
		 #获取tr标签包裹的元素,总共100个元素
		while($tbody =~ /(\<tr.*?\>.*?\<\/tr\>)/ig){#g为全局匹配，一定要加
			#遍历td标签，总共8个
		  	my $td=$1;				
			my @tds = ();			
			$trs[$ind++] = \@tds;#存放tds，如ind=0时，存放8个该排名的td
			
			while($td =~ /\<td[\s|\>](.*?)\<\/td\>/ig ){
				
				push @tds,$1;
			}
			#处理td
			# 0	Id
			# 1 Description
			# 2-6	Max score	Total score	Query coverage	E value	Ident	
			# 7	Accession
			($tds[0]) = $tds[0] =~ /value=\"(.*?)\"/i;#注，1包裹自己,2添加标志物,
			
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
	功能：获取指定排名的结果，并根据结果中的id下载数组，并获取taxon
	结果：
	参数：$rank-排名
	返回：
=cut	
sub get_rank(){	 
	my ($rank, $seq_name, $query_index, $trs_arr_ref) = @_;
	
		my @trs = @$trs_arr_ref;		
		 # 根据需求获取特定数目的排名
		foreach my $ind(0..$rank-1){
			# print $trs[$ind],"\n";#获取rank个排名
			# 获取嵌套数组引用
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
			#打印结果信息
			print "Query Seq_name: $seq_name, Rank: ",$ind+1," success.\nNow showing and saving it's Taxonomy, Taxon and Score Table\n\n\n";			
			print "$result_table[$_+1]:\t$tds[$_]\n" foreach(0..7);
			print "$result_table[9]:\t$taxon\n";
			print "Taxonomy:\t$organism";
			
			#保存文件
			print OUTPUT "$seq_name\t";
			print OUTPUT "$_\t" foreach(@tds);
			print OUTPUT "$taxon\t";
			print OUTPUT "$organism\n";
			
}			
	}	
	
=head
	功能：获取id对应的序列信息。
	结果：保存文件，返回taxon
	参数：排名：rank，id： 文件夹名:$gbs_dir
	返回：taxon
=cut
sub get_taxon(){
	my ($id,$rank) = @_;
	
	my $url = "https://www.ncbi.nlm.nih.gov/sviewer/viewer.cgi?id=$id";
	my $res = $ua->get($url)->content; 
	my ($taxon) = $res=~/\/db_xref\=\"taxon:(.*?)\"/i;
	#处理网页信息
#	print $taxon;
	#保存网页内容
	# open(OUT, ">$dir/rank_$rank+id_$id.gb");
	# select OUT;
	# print $res;
	# close OUT;   
	
	return $taxon;
}			
		
=head
	功能：获取物种分类
	参数：taxon
=cut	
sub get_specials(){
	use LWP::UserAgent; 	
	my ($taxon) = @_;																			
	my $tax_url="https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi";  #设置发送请求的网页url	
	my $res=LWP::UserAgent->new->post($tax_url,['name'=>$taxon]);  		#在目的页面发送post请求
	my @web = split( /\r?\n/, $res->content);			#把源代码以回车分裂成多行
	
	my @bio_info =qw(superkingdom phylum class order family genus species);	
	
	my ($target_line,$organism)="";
	foreach my $line(@web){
		my $i = 0;
		foreach(@bio_info){#如果匹配成功,则匹配个数+1
			if ($line =~ /($_)/){
				$i++;
				if ($i >=2){#如果出现的数大于2次,则退出当前
					$target_line = $line;
					last;						
					}							
				} 
			}
		last if($target_line);#当查找到目的行即退出	
		}
		#获取参数
	foreach(0...6){		
		if($target_line =~ /(\=\"$bio_info[$_]\">)([^<>]*)(<\/)/){
			$organism .= "$2\t";	
		}else{
			$organism .= "\t";
			}			
	}
	return $organism;
}
#处理多个序列
#遍历上传的文件，获取序列名，存入数组中
=head
	功能：处理上传的fasta文件
	结果：数组：索引代表序号，0-（序列数目-1）
				内容为序列名
	参数：fasta格式文件名			
	返回：数组引用
=cut
sub get_seqs_name(){
	my ($in_file) = @_;
	my @seqs_name=();	#存放序列名
	open(FASTA,$in_file)or die "file error";
	foreach(<FASTA>){
		if($_ =~ /^>([^\s]*)\s/){
			push @seqs_name,$1;#将序列名与获取的taxon_id所对应

			}
		}
	close FASTA ;
	return \@seqs_name;
	}
	
	
	
#初始化参数
sub init_parms(){
	
	&load_blast_parms();#载入blast参数	
	&load_database_parms();#载入菜单的参数
	
	&load_table_parms();#载入表单传递的参数		
	&load_table_header();#载入结果文件的表头
}
###################################  DATA  ############################
#载入blast参数	
sub load_blast_parms {
	$blast_value[0]="Blastn  (nucleotide - nucleotide BLAST)";#megaBlast;
	$blast_value[1]="Tblastn (translated nucleotide - protein BLAST) ";#tblastn
	$blast_value[2]="Tblastx (translated nucleotide - translated nucleotide BLAST)";#tblastx
	$blast_value[3]="Blastp  (protein-protein BLAST)";#blastp
	$blast_value[4]="Blastx  (protein - translated nucleotide BLAST)";	#blastx	
	
}
#载入菜单的参数
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
#载入表单传递的参数
sub load_table_parms {
	
	#<!-- blastn, megablast, discomegablast, tblastn, tblastx -->  
	$database01_name[0]="GPIPE/9606/current/all_top_level GPIPE/9606/current/rna";
	$database01_name[1]="GPIPE/10090/current/all_top_level GPIPE/10090/current/rna";
	$database01_name[2]="nr";#默认
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
	$database02_name[0]="nr";#默认
	$database02_name[1]="refseq_protein";
	$database02_name[2]="SMARTBLAST/landmark";
	$database02_name[3]="swissprot";
	$database02_name[4]="pat";
	$database02_name[5]="pdb";
	$database02_name[6]="env_nr";
	$database02_name[7]="tsa_nr";	
}
#载入结果表头
sub load_table_header {
	#建立表头-要获取的所有信息
	@result_table =qw(Seq_name Gi Description Max_score 
		Total_score Query_cover E_value Ident Accession
		Taxon 
		Superkingdom Phylum Class Order Family Genus Species);
}	


#主菜单
#功能：提示用户键入input—file	
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
		
	#1.提示用户输入文件名。
	print "Now, Please Input Your FASTA File Name:";
	
	my $file_name=<STDIN>;chomp $file_name;	
	return $file_name;			
}


#blast菜单
sub load_blast_menu {
	#2.让用户设置参数1：算法。
	#print "filename\t$file_name";
	print "\n\n\n*************Please Choose Web BLAST*************\n\n\n";
	for (my$i=0;$i<@blast_value;$i++){
		print "\t$i. $blast_value[$i]\n";
	}
	print "\n\n\nYour choose: ";

	return <STDIN>;	
}

#database菜单
sub load_database_menu {
	#3.让用户设置参数2：数据库。（算法与数据库相绑定，具有联动关系） 
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
#rank菜单
sub load_rank_menu {
	
	print "*************Please Set Rank [1..100] For Blast*************\n\n";
	print "Rank : ";
	
	return <STDIN>;	
}
#output菜单
sub load_output_menu {
	
	print "*************Please Set Output File For Saving Result*************\n\n\n"; 
	
	return <STDIN>;	
}	