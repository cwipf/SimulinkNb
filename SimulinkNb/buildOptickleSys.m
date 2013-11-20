function buildOptickleSys(optName,fVecName,inputs,outputs)
%buildOptickleSys Creates an Optickle based subsystem for simulinkNB
    
    opt = evalin('caller',optName);

    if nargin<3
        inputs = getDriveNames(opt);
    end

    if nargin<4
        probearray = opt.probe;

        for j =1:length(probearray)
            outputs{j} = probearray(j).name; 
        end
    end

    % some
    
    origin.Inport = [20 50 50 70];
    offset.Inport = [0 100 0 100];
    origin.opt = [200 20 500 600];
    origin.optInport = origin.Inport;
    offset.optInport = offset.Inport;
    origin.Outport = [800 50 830 70];
    offset.Outport = offset.Inport;
    origin.optOutport = origin.Outport;
    offset.optOutport = offset.Outport;
    origin.noiseBlock = origin.Outport - [150 50 150 50];
    offset.noiseBlock = offset.Outport;
    origin.internalSum = [400 20 425 400];
    origin.outputSum = [700 50 720 70];
    offset.outputSum = offset.Outport;
    
    base = 'opt';
    new_system(base)
    sys = [base '/OptickleModel'];
    add_block('built-in/SubSystem',sys,'Position',origin.opt,'BackGroundColor','purple');
    
    
    % add the optickleFrd block
    optFrd = add_block('built-in/SubSystem',[sys '/' optName]);
    set(optFrd,'Position',origin.opt);
    set(optFrd,'AttributesFormatString','%<Description>');
    set(optFrd,'Description',['flexTF: optickleFrd(' optName ',' fVecName ')']);
    
    % add internals of optickleFrd
    sumblock = add_block('built-in/Sum',[sys '/' optName '/Sum']);
    set(sumblock,'Position',origin.internalSum);
    set(sumblock,'IconShape','rectangular');
    set(sumblock,'Inputs',repmat('+',1,length(inputs)));
    
    % loop on inputs
    for jj = 1:length(inputs);
        input = inputs{jj};
        % inputs
        add_block('built-in/Inport',[sys '/' input],'Position',origin.Inport+(jj-1)*offset.Inport);
        % optickleFrd inputs
        add_block('built-in/Inport',[sys '/' optName '/' input],'Position',origin.optInport+(jj-1)*offset.optInport);
        
        % add links
        add_line(sys,[input '/1'],[optName '/' num2str(jj)],'autorouting','on');
        add_line([sys '/' optName],[input '/1'],['Sum/' num2str(jj)],'autorouting','on');
    end
    
    % loop on outputs
    for jj = 1:length(outputs);
        output = outputs{jj};
        % outputs
        add_block('built-in/Outport',[sys '/' output],'Position',origin.Outport+(jj-1)*offset.Outport);
        % optickleFrd outputs
        add_block('built-in/Outport',[sys '/' optName '/' output],'Position',origin.optOutport+(jj-1)*offset.optOutport);
        
        % add the noiseblock
        noiseBlock = add_block('NbLibrary/NbNoiseSource',[sys '/' output '_Noise']);
        set(noiseBlock,'Position',origin.noiseBlock+(jj-1)*offset.noiseBlock);
        set(noiseBlock,'asd',['optickleNoiseBlock(' optName ',' fVecName ',''' output ''')'])
        set(noiseBlock,'groupNest','2');
        set(noiseBlock,'group','''Quantum Noise''');
        set(noiseBlock,'subgroup',['''' output '''']);
        
        % add sum block
        sumblock = add_block('built-in/Sum',[sys '/Sum' num2str(jj)]);
        set(sumblock,'Position',origin.outputSum + (jj-1)*offset.outputSum);
        set(sumblock,'IconShape','round');
        set(sumblock,'Inputs','++|');
        
        % add links
        add_line([sys '/' optName],'Sum/1',[output '/1'],'autorouting','on');
        add_line(sys,[output '_Noise/1'],['Sum' num2str(jj) '/1'],'autorouting','on');
        add_line(sys,[optName '/' num2str(jj)],['Sum' num2str(jj) '/2'],'autorouting','on');
        add_line(sys,['Sum' num2str(jj) '/1'],[output '/1'],'autorouting','on');
    end

    open_system(base);
    
end