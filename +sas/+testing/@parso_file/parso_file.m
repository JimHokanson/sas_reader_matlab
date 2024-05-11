classdef parso_file
    %
    %   

    properties
        columns
        compression_method
        date_created
        data_modified
        deleted_row_count
        encoding
        endianess
        file_label
        file_type
        header_length
        mix_page_row_count
        name
        os_name
        os_type
        page_count
        page_length
        row_count
        row_length
        sas_release
        server_type
        session_encoding
        is_compressed
        is_u64
    end

    methods
        function obj = parso_file(columns,p)
            obj.columns = columns;
            obj.compression_method = p.getCompressionMethod();
            obj.date_created = p.getDateCreated();
            obj.data_modified = p.getDateModified();
            obj.deleted_row_count = p.getDeletedRowCount();
            obj.encoding = char(p.getEncoding());
            obj.endianess = p.getEndianness();
            obj.file_label = char(p.getFileLabel());
            obj.file_type = char(p.getFileType());
            obj.header_length = p.getHeaderLength();
            obj.mix_page_row_count = p.getMixPageRowCount();
            obj.name = char(p.getName());
            obj.os_name = char(p.getOsName());
            obj.os_type = char(p.getOsType());
            obj.page_count = p.getPageCount();
            obj.page_length = p.getPageLength();
            obj.row_count = p.getRowCount();
            obj.row_length = p.getRowLength();
            obj.sas_release = char(p.getSasRelease());
            obj.server_type = char(p.getServerType());
            obj.session_encoding = p.getSessionEncoding();
            obj.is_compressed = p.isCompressed();
            obj.is_u64 = p.isU64();
        end
    end
end