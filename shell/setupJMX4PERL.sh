#!/bin/bash
# William Lam
# www.williamlam.com
# Script to download & install jmx4perl

if [ $(id -u) -ne 0 ]; then
        echo -e "\nScript needs to be executed using sudo\n"
        exit 1
fi

mkdir -p jmx4perl

wget http://search.cpan.org/CPAN/authors/id/R/RO/ROLAND/jmx4perl-1.06.tar.gz -O jmx4perl/jmx4perl-1.06.tar.gz
wget http://search.cpan.org/CPAN/authors/id/C/CR/CRENZ/Module-Find-0.11.tar.gz -O jmx4perl/Module-Find-0.11.tar.gz
wget http://search.cpan.org/CPAN/authors/id/B/BR/BRONSON/Term-ShellUI-0.92.tar.gz -O jmx4perl/Term-ShellUI-0.92.tar.gz
wget http://search.cpan.org/CPAN/authors/id/T/TL/TLINDEN/Config-General-2.51.tar.gz -O jmx4perl/Config-General-2.51.tar.gz
wget http://search.cpan.org/CPAN/authors/id/P/PJ/PJB/Term-Clui-1.66.tar.gz -O jmx4perl/Term-Clui-1.66.tar.gz
wget http://search.cpan.org/CPAN/authors/id/M/MA/MAKAMAKA/JSON-2.53.tar.gz -O jmx4perl/JSON-2.53.tar.gz

cd jmx4perl

tar -zxvf JSON-2.53.tar.gz
tar -zxvf Term-Clui-1.66.tar.gz
tar -zxvf Config-General-2.51.tar.gz
tar -zxvf Term-ShellUI-0.92.tar.gz
tar -zxvf Module-Find-0.11.tar.gz
tar -zxf jmx4perl-1.06.tar.gz

cd JSON-2.53
perl Makefile.PL
make
make install

cd ..
cd Term-Clui-1.66
perl Makefile.PL
make
make install

cd ..
cd Config-General-2.51
perl Makefile.PL
make
make install

cd ..
cd Term-ShellUI-0.92
perl Makefile.PL
make
make install

cd ..
cd Module-Find-0.11
perl Makefile.PL
make
make install

cd ..
cd jmx4perl-1.06
perl Build.PL
./Build
./Build install
