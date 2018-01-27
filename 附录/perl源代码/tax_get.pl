
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

#�����ļ�
open(OUT,">ncbi.reg.out");
#��ӡ��ͷ					
print OUT "$bio_info$organism_info\n";	
close OUT;
	
=head
	���ܣ�����taxon�ļ�,ȥ���ظ���taxon
	�������ļ���
	���أ���ѯ����������Ϣ
=cut
sub load_file{
	my($file)=@_;

	open (OUT,$file) or die "can't read this file";		
	my @file_data = <OUT>;close OUT; 	
	chomp @file_data;
	
	my %taxon_class=();#���ڴ��taxon����Classifion����ȥ��
	if((shift @file_data) eq ">taxon"){#�ж��Ƿ����ض��ļ�		
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
	���ܣ�ͨ������taxon/special name ��ȡ��Ӧ��������Ϣ
	������taxon
	���أ���������������
=cut

sub getSpecials(){
	use LWP; 	
	my ($taxon) = @_;																			
	my $tax_url="https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi";  #���÷����������ҳurl	
	my $response=LWP::UserAgent->new->post($tax_url,['name'=>$taxon]);  		#��Ŀ��ҳ�淢��post����
	my @web = split( /\r?\n/, $response->content);			#��Դ�����Իس����ѳɶ���
	
	my @bio_info =qw(superkingdom phylum class order family genus species);	
	
	my $target_line;
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
	#�п�	
	if (!$target_line){
		print "\#taxon: $taxon doesn't have right Taxonomy from NCBI\n";
		next;
	}
	#��ȡ����
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
