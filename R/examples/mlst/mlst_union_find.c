#include <R.h>
#include <Rinternals.h>

static int find_root(int *parent, int item) {
    while (parent[item] != item) item = parent[item];
    return item;
}

SEXP cg_marginal_component_reduction(SEXP ids_s, SEXP count_s, SEXP edges_s) {
    int count = asInteger(count_s), edge_count = nrows(edges_s), merges = 0;
    if (count <= 1) return ScalarInteger(0);
    const int *ids = INTEGER(ids_s), *edges = INTEGER(edges_s);
    int *parent = (int *) R_alloc((size_t) count, sizeof(int));
    for (int i = 0; i < count; ++i) parent[i] = i;
    for (int i = 0; i < edge_count; ++i) {
        int first = find_root(parent, ids[edges[i] - 1] - 1);
        int second = find_root(parent, ids[edges[i + edge_count] - 1] - 1);
        if (first != second) { parent[second] = first; ++merges; }
    }
    return ScalarInteger(merges);
}

SEXP cg_add_label_to_state(SEXP ids_s, SEXP count_s, SEXP edges_s) {
    int count = asInteger(count_s), edge_count = nrows(edges_s), merges = 0;
    const int *ids = INTEGER(ids_s), *edges = INTEGER(edges_s);
    R_xlen_t node_count = XLENGTH(ids_s);
    int *parent = (int *) R_alloc((size_t) count, sizeof(int));
    for (int i = 0; i < count; ++i) parent[i] = i;
    for (int i = 0; i < edge_count; ++i) {
        int first = find_root(parent, ids[edges[i] - 1] - 1);
        int second = find_root(parent, ids[edges[i + edge_count] - 1] - 1);
        if (first != second) { parent[second] = first; ++merges; }
    }

    SEXP new_ids_s = PROTECT(allocVector(INTSXP, node_count));
    int *new_ids = INTEGER(new_ids_s);
    if (merges == 0) {
        for (R_xlen_t i = 0; i < node_count; ++i) new_ids[i] = ids[i];
    } else {
        int *root_to_id = (int *) R_alloc((size_t) count, sizeof(int));
        int *compact = (int *) R_alloc((size_t) count, sizeof(int));
        for (int i = 0; i < count; ++i) root_to_id[i] = 0;
        int next_id = 0;
        for (int component = 0; component < count; ++component) {
            int root = find_root(parent, component);
            if (root_to_id[root] == 0) root_to_id[root] = ++next_id;
            compact[component] = root_to_id[root];
        }
        for (R_xlen_t i = 0; i < node_count; ++i)
            new_ids[i] = compact[ids[i] - 1];
    }

    SEXP result = PROTECT(allocVector(VECSXP, 2));
    SEXP names = PROTECT(allocVector(STRSXP, 2));
    SET_VECTOR_ELT(result, 0, new_ids_s);
    SET_VECTOR_ELT(result, 1, ScalarInteger(count - merges));
    SET_STRING_ELT(names, 0, mkChar("component_ids"));
    SET_STRING_ELT(names, 1, mkChar("component_count"));
    setAttrib(result, R_NamesSymbol, names);
    UNPROTECT(3);
    return result;
}
