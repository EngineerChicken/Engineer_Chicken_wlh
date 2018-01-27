
use strict;

print "\n\n\n".
"		*************************************************\n".
"		*****************  Tax Get  *********************\n".
"		*************************************************".
		"\n\n\n".
		"[STEP]\n".
		"	1. Input Taxons File From Disc\n".
		"	2. Wait Output File\n\n\n";	
print "Your Taxons_File_Name:";
my $file = <STDIN>;
print "\n\n";
my $organism_info = &load_file($file);
my $bio_info = "taxon_id\tsuperkingdom\tphylum\tclass\torder\tfamily\tgenus\tspecies\n";

#保存文件
open(OUT,">ncbi.reg.out");
#打印表头					
print OUT "$bio_info$organism_info\n";	
close OUT;
	
=head
	功能：载入taxon文件,去除重复的taxon
	参数：文件名
	返回：查询到的物种信息
=cut
sub load_file{
	my($file)=@_;

	open (OUT,$file) or die "can't read this file";		
	my @file_data = <OUT>;close OUT; 	
	chomp @file_data;
	
	my %taxon_class=();#用于存放taxon——Classifion，并去重
	if((shift @file_data) eq ">taxon"){#判断是否是特定文件		
		foreach(@file_data){
			$taxon_class{$_}="";			
		}
							
	foreach my$key(keys %taxon_class)	{
		print "Now querying taxon: $key\n";
		$taxon_class{$key} = &getSpecials($key);					
		}	
	
	my $organism_info="";	
		foreach(@file_data)	{
			$organism_info.="$_\t$taxon_class{$_}\n";
		}		
	return $organism_info;
	
	}else{
		print "Please Input right Taxons_File";
		exit;
	}		
						
	}

=head
	功能：通过传入taxon/special name 获取对应的物种信息
	参数：taxon
	返回：结果数组的引用他
=cut

sub getSpecials(){
	use LWP; 	
	my ($taxon) = @_;																			
	my $tax_url="https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi";  #设置发送请求的网页url	
	my $response=LWP::UserAgent->new->post($tax_url,['name'=>$taxon]);  		#在目的页面发送post请求
	my @web = split( /\r?\n/, $response->content);			#把源代码以回车分裂成多行
	
	my @bio_info =qw(superkingdom phylum class order family genus species);	
	
	my $target_line;
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
	#判空	
	if (!$target_line){
		print "\#taxon: $taxon doesn't have right Taxonomy from NCBI\n";
		next;
	}
	#获取参数
	my $taxonomy="";
	foreach(0...6){		
		if($target_line =~ /(\=\"$bio_info[$_]\">)([^<>]*)(<\/)/){
			$taxonomy .= "\t$2";	
		}else{
			$taxonomy .= "\t";
			}			
	}
	return $taxonomy;
}
