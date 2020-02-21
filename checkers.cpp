#include<iostream>
using namespace std;
int main()
{
 char a;
 cout<<"Are you ready? y/n ";
 cin>>a;
 switch(a)
 {
  case 'y':
      cout<<"Done!!!"<<endl;
      break;
  case 'n':
      cout<<"Oh shit"<<endl;
      break;
  default:
      cout<<"Error"<<endl;
 }
 return 0;
}