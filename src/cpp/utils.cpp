#include "utils.hpp"

/*** READ RHS AND EXACT SOLUTIONS VECTORS ***/

void SourceFieldMetadata::print(const std::string& filename) {
    std::ofstream file(filename);
        file << "{\n"
             << "  \"grid_nx\": " << grid_nx << ",\n"
             << "  \"grid_ny\": " << grid_ny << ",\n"
             << "  \"iterations\": " << iterations << ",\n"
             << "  \"fixed_point\": {\n"
             << "    \"total_bits\": "<< fixed_point.total_bits <<",\n"
             << "    \"fractional_bits\": "<< fixed_point.fractional_bits <<",\n"
             << "    \"signed\": " << (fixed_point.is_signed ? "true" : "false") << "\n"
             << "  },\n"
             << "  \"dtype\": \"int" << fixed_point.total_bits << "\",\n"
             << "  \"endianness\": \"little\",\n"
             << "  \"layout\": \"row_major\",\n"
             << "  \"boundary\": \"dirichlet_zero\"\n"
             << "}\n";
}

namespace {

std::string read_text_file(const std::string& filename) {
    std::ifstream file(filename.c_str());
    if (!file) {
        std::cerr <<"could not open metadata file: " << filename << std::endl;
        exit(-1);
    }

    return std::string(std::istreambuf_iterator<char>(file),
                       std::istreambuf_iterator<char>());
}

std::string json_value(const std::string& json, const std::string& key) {
    const std::size_t key_pos = json.find("\"" + key + "\"");
    const std::size_t value_begin = json.find_first_not_of(" \t\r\n", json.find(':', key_pos) + 1);

    if (json[value_begin] == '"') {
        const std::size_t string_end = json.find('"', value_begin + 1);
        return json.substr(value_begin + 1, string_end - value_begin - 1);
    }

    const std::size_t value_end = json.find_first_of(",}\r\n", value_begin);
    return json.substr(value_begin, value_end - value_begin);
}

}  // namespace


SourceFieldMetadata read_source_field_metadata(const std::string& filename) {
    const std::string json = read_text_file(filename);

    SourceFieldMetadata metadata;
    metadata.grid_nx = std::stoi(json_value(json, "grid_nx"));
    metadata.grid_ny = std::stoi(json_value(json, "grid_ny"));
    metadata.iterations = std::stoi(json_value(json, "iterations"));
    metadata.fixed_point.total_bits = std::stoi(json_value(json, "total_bits"));
    metadata.fixed_point.fractional_bits = std::stoi(json_value(json, "fractional_bits"));
    metadata.fixed_point.is_signed = json_value(json, "signed") == "true";
    metadata.dtype = json_value(json, "dtype");
    metadata.endianness = json_value(json, "endianness");
    metadata.layout = json_value(json, "layout");
    metadata.boundary = json_value(json, "boundary");
    return metadata;
}
