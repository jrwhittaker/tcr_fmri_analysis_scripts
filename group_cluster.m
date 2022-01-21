%
% Code for doing k-means clustering of group TCR response
%
% Joe Whittaker (2021)

% Mask directory
mdir='/home/sapjw12/code/metric/templates/tpl-MNI152NLin2009cAsym';

% Read in group average fitted response and reshpae into matrix
img=rn('all.basis_fitts_psc.5mm.nii.gz');
[nx,ny,nz,nt]=size(img);
imat=reshape(img,nx*ny*nz,nt);
imat=imat./(max(abs(imat'))'*ones(1,90));

% Read in functional mask and reshape into matrix
mset='fMRIPrep_boldref_mask.nii.gz';
mimg=rn([mdir filesep mset]);
mmat=reshape(mimg,nx*ny*nz,1);
mIdx=find(mmat>0);

mat=imat(mIdx,:);

% Specify cluster sizes
nclusts=[2 4 8];

% Cluster data and assign cluster images to cell array
for kk=1:3
    kclusts=nclusts(kk);
    [kIdx(:,1),~,sumd]=kmeans(imat(mIdx,21:90),kclusts,'Start','cluster');
    kimg=zeros(size(mmat));
    kimg(mIdx,:)=kIdx;
    kimg=reshape(kimg,nx,ny,nz);
    KIMG{kk}=kimg;
    KIDX{kk}=kIdx;
end

% Slices for visualisation
sliceIdx=18:6:66;
tmp=imat(mIdx,:);

% Custom color map
cmap=[1.0 1.0 1.0;...
      0.0 0.0 1.0;...
      0.0 1.0 0.0;...
      0.98 0.64 0.1;...
      1.0 0.0 1.0;...
      0.2 0.87 1.0;...
      1.0 0.0 0.0];

% Plot cluster spatial maps and average time-series
figure
  for n=1:9
      subplot(6,3,n)
      imagesc(flipud(squeeze(KIMG{1}(:,:,sliceIdx(n))')),[0 6]);
      colormap(cmap);
      set(gca,'xtick',[]);
      set(gca,'ytick',[]);
      axis off
  end
  subplot(6,3,[10:18])
  for m=1:2
      plot(mean(tmp(KIDX{1}==m,:)),'color',cmap(m+1,:),'LineWidth',2);
      hold on
  end
  hold off
  axis('square',[20 90 -1 1]);
  set(gca,'xtick',[20 40 60 80],'xticklabel',{'0','20','40','60'});
  set(gca,'ytick',[]);
  xlabel('Post TCR time (s)','Interpreter','latex','FontSize',20);
  set(gca,'LineWidth',2,'TickLength',[0 0],'FontSize',16);
  grid on
  
  figure
  for n=1:9
      subplot(6,3,n)
      imagesc(flipud(squeeze(KIMG{2}(:,:,sliceIdx(n))')),[0 6]);
      colormap(cmap);
      %axis('square');
      set(gca,'xtick',[]);
      set(gca,'ytick',[]);
      axis off
  end
  subplot(6,3,[10:18])
  for m=1:4
      plot(mean(tmp(KIDX{2}==m,:)),'color',cmap(m+1,:),'LineWidth',2);
      hold on
  end
  hold off
  axis('square',[20 90 -1 1]);
  set(gca,'xtick',[20 40 60 80],'xticklabel',{'0','20','40','60'});
  set(gca,'ytick',[]);
  xlabel('Post TCR time (s)','Interpreter','latex','FontSize',20);
  set(gca,'LineWidth',2,'TickLength',[0 0],'FontSize',16);
  grid on
  
  figure
  for n=1:9
      subplot(6,3,n)
      imagesc(flipud(squeeze(KIMG{3}(:,:,sliceIdx(n))')),[0 6]);
      colormap(cmap);
      set(gca,'xtick',[]);
      set(gca,'ytick',[]);
      axis off
  end
  subplot(6,3,[10:18])
  for m=1:6
      plot(mean(tmp(KIDX{3}==m,:)),'color',cmap(m+1,:),'LineWidth',2);
      hold on
  end
  hold off
  axis('square',[20 90 -1 1]);
  set(gca,'xtick',[20 40 60 80],'xticklabel',{'0','20','40','60'});
  set(gca,'ytick',[]);
  xlabel('Post TCR time (s)','Interpreter','latex','FontSize',20);
  set(gca,'LineWidth',2,'TickLength',[0 0],'FontSize',16);
  grid on


