import streamlit as st
import pandas as pd
import streamlit as st
import networkx as nx
from pyvis.network import Network
from pandas.api.types import is_categorical_dtype, is_numeric_dtype

def main():
    if "dataframes" not in st.session_state:
        st.session_state.dataframes = {
            "formulated_drugs": pd.read_csv("csv_files/formulated_drugs.csv"),
            "drug_products": pd.read_csv("csv_files/drug_products.csv"),
            "excipients": pd.read_csv("csv_files/excipients.csv"),
            "formulations": pd.read_csv("csv_files/formulations.csv"),
            "parent_drugs": pd.read_csv("csv_files/parent_drugs.csv"),
            "association_rules": pd.read_csv("csv_files/streamlit_app_data.csv") 
        }

    if "page" not in st.session_state:
        st.session_state.page = 1
    if "show_expanders" not in st.session_state:
        st.session_state.show_expanders = False
    if "active_tab" not in st.session_state:
        st.session_state.active_tab = None

    st.set_page_config(page_title="Pharmacoinformatics Repository", layout="wide")

    introduction = """
        ### Introduction:

        Data-driven decision-making is poised to drive the efficiency of the pharmaceutical industry. Existing sources of
        data, however, do not adequately support drug product development. This page was built as part of a study (**currently under review in _Molecular Pharmaceutics_**) that
        used web scraping to construct a highly linked drug product database.

        Use the buttons below to explore two applications built using this data:
    """
    st.markdown(
        """
        <style>
        .center-title {
            text-align: center;
            font-size: 2.5em;
            font-weight: bold;
        }
        </style>
        """,
        unsafe_allow_html=True
    )
    st.markdown('<div class="center-title">💊 Pharmacoinformatics Database  💊</div>', unsafe_allow_html=True)
    st.markdown(introduction)

    def explore_database():
        st.markdown("""
        Use the search bar below to see if a particular drug product is captured by our database! Searches are filtered by the product"s
        proprietary name as it appears in the European Medicines Agency central register. Click "More Details" to learn more about the product.

        Please note that this interface is intended for illustrative purposes only, and not all data fields are accessible via this interface.
        """)
        def display_tile_interface(active_tab):
            search_term = st.text_input(f"{active_tab.replace("_", " ").title()} search:")
            df = st.session_state.dataframes[active_tab]
            
            # Reset the page number to 1 
            if search_term:
                st.session_state.page = 1
            
            # Filter DataFrame 
            if search_term:
                filtered_df = df[ 
                    df.apply(lambda row: row.astype(str).str.contains(search_term, case=False).any(), axis=1)
                ]
            else:
                filtered_df = df

            results_per_page = 12
            total_results = len(filtered_df)
            total_pages = (total_results // results_per_page) + (1 if total_results % results_per_page > 0 else 0)
            start_idx = (st.session_state.page - 1) * results_per_page
            end_idx = start_idx + results_per_page
            page_results = filtered_df.iloc[start_idx:end_idx]
            
            # Make result tiles
            st.subheader(f"🔍 Search Results for {active_tab.replace("_", " ").title()}:")
            num_cols = 4 
            for i in range(0, len(page_results), num_cols):
                cols = st.columns(num_cols)
                for j, row in enumerate(page_results.iloc[i:i + num_cols].itertuples()):
                    with cols[j]:
                        with st.expander(f"{row.product_name}", expanded=False):
                            st.write("**Product ID:**", row.product_id)
                            st.write("**ATC Code:**", row.atc_code)
                            st.write("**Authorization Status:**", row.authorisation_status)
                            st.write("**Dosage Form:**", row.dosage_form)
                            st.write("**Therapeutic Group:**", row.therapeutic_group)
                            if st.button("More Details", key=f"details_{row.product_id}"):
                                st.session_state.selected_product_id = row.product_id
                                st.session_state.selected_product_name = row.product_name
                                st.session_state.show_expanders = True

            col_arrow = st.columns([1, 1]) 
            with col_arrow[0]:
                prev_next_cols = st.columns([1, 1]) 
                with prev_next_cols[0]:
                    if st.button("◀", key="prev_page") and st.session_state.page > 1:
                        st.session_state.page -= 1
                with prev_next_cols[1]:
                    if st.button("▶", key="next_page") and st.session_state.page < total_pages:
                        st.session_state.page += 1
            st.write(f"Total results found: {total_results} | Page {st.session_state.page} of {total_pages}")

        # Display detail about product
        def display_product_details():
            if "selected_product_id" in st.session_state:
                product_id = st.session_state.selected_product_id
                product_name = st.session_state.selected_product_name
                product_df = st.session_state.dataframes["drug_products"]
                product_details = product_df[product_df["product_id"] == product_id].iloc[0]
                product_info = {
                    "Product Name": product_details["product_name"],
                    "EMA Number": product_details["ema_number"],
                    "Authorization Status": product_details["authorisation_status"],
                    "Therapeutic Group": product_details["therapeutic_group"],
                    "Dosage Form": product_details["dosage_form"],
                    "Route of Administration": product_details["route"],
                    "Indication": product_details["indication"],
                    "Authorisation Date": product_details["authorisation_date"],
                    "Authorisation Holder": product_details["authorisation_holder"]
                }
                
                product_info_df = pd.DataFrame(list(product_info.items()), columns=["Attribute", "Value"])
                st.subheader(f"📈 Detailed Information for {product_name} (Product ID: {product_id}):")
                st.table(product_info_df)
                display_boolean_row(product_details)

        def display_boolean_row(product_details):
            cols = st.columns(7) 
            boolean_fields = {
                "Additional Information": product_details["additional"],
                "Generic": product_details["generic"],
                "Orphan Drug": product_details["orphan"],
                "Exceptional Authorization": product_details["exceptional"],
                "Accelerated Approval": product_details["accelerated"],
                "Conditional Approval": product_details["conditional"],
                "Patient Safety": product_details["patient_safety"]
            }

            for idx, (label, value) in enumerate(boolean_fields.items()):
                with cols[idx]:
                    display_boolean_box(value, label)
        # True false boxes
        def display_boolean_box(value, label):
            color = "#28a745" if value else "#dc3545"  
            text = "<b>True</b>" if value else "<b>False</b>" 
            box_style = "display: inline-block; padding: 8px 16px; background-color: {}; color: white; border-radius: 5px; font-size: 14px; text-align: center; width: 120px; margin: 4px;".format(color)
            st.markdown(f"<div style='{box_style}'>{label}: <br>{text}</div>", unsafe_allow_html=True)

        if st.session_state.active_tab in st.session_state.dataframes:
            display_tile_interface(st.session_state.active_tab)

        if "selected_product_id" in st.session_state:
            display_product_details()

        st.markdown("<div style='height: 20px;'></div>", unsafe_allow_html=True)
        
        if st.session_state.get("show_expanders", False):

            # Retrieve DataFrames
            formulated_drugs_df = st.session_state.dataframes["formulated_drugs"]
            excipients_df = st.session_state.dataframes["excipients"]
            formulations_df = st.session_state.dataframes["formulations"]
            parent_drugs_df = st.session_state.dataframes["parent_drugs"]

            # Filter
            drugs_complete_df = formulated_drugs_df.merge(parent_drugs_df, on="parent_drug_id", how="left")
            drug_entries = drugs_complete_df[drugs_complete_df["product_id"] == st.session_state.selected_product_id]

            # Merge 
            formulations_excipients_df = formulations_df.merge(excipients_df, on="excipient_id", how="left")
            excipient_entries = formulations_excipients_df[formulations_excipients_df["product_id"] == st.session_state.selected_product_id]
            col_expander1, col_expander2 = st.columns(2)

            # Begin expanders
            with col_expander1:
                st.subheader("Drug(s):")
                column_names = {
                    "drug_substance": "Drug Substance in Product",
                    "actives_by_dose": "Form of drug that dose refers to",
                    "fa": "Bioavailability (fa)",
                    "f": "Fraction Absorbed (f)",
                    "tmax": "Time to Maximum Plasma Concentration in hours (tmax)",
                    "vdss": "Volume of Distribution at steady state (L/kg)",
                    "clearance": "Clearance (mL/min)",
                    "fraction_unbound": "Fraction Unbound",
                    "mrt": "Mean Residence Time (hours)",
                    "terminal_half_life": "Terminal Half-Life (hours)",
                    "dose_value": "Dose",
                    "dose_unit": "Dose Unit",
                    "pss_inchi": "Formulated drug InChI",
                    "pss_inchikey": "Formulated drug InChI Key",
                    "pss_smiles": "Formulated drug SMILES",
                    "p_inchi": "Parent InChI",
                    "p_inchikey": "Parent InChI Key",
                    "p_smiles": "Parent SMILES",
                    "p_chembl_id": "Parent ChEMBL ID",
                    "notes": "Curation nodes"
                }
                for i, row in drug_entries.iterrows():
                    with st.expander(f"{row["drug_substance"]}"):
                        for column, display_name in column_names.items():
                            value = row.get(column, None)
                            if pd.notna(value): 
                                st.write(f"**{display_name}:** {value}", unsafe_allow_html=True)

            with col_expander2:
                st.subheader("Excipient(s):")
                column_names_excipient = {
                    "product_id": "Product ID",
                    "excipient_id": "Excipient ID",
                    "excipient_name": "Excipient Name",
                    "excipient_inchi": "Excipient InChI",
                    "excipient_inchikey": "Excipient InChI Key",
                    "excipient_chembl_id": "Excipient ChEMBL ID",
                    "excipient_pchem_cid": "Excipient PubChem CID"
                }

                for i, row in excipient_entries.iterrows():
                    with st.expander(f"{row["excipient_name"]}"):
                        for column, display_name in column_names_excipient.items():
                            value = row.get(column, None)
                            if pd.notna(value): 
                                st.write(f"**{display_name}:** {value}", unsafe_allow_html=True)

    # Association rules
    def explore_rules():
        st.markdown("""
            This tool allows you to explore association rules for excipient selection in oral tablets. The 
            table below can be filtered on any field and an **interactive** association network will be automatically generated.
            The filtered data can be exported by clicking the "download" button at the top right of the table.  Only
            rules with one antecedent and one consequent are shown for simplicity. 
            
            Beneath the table, an **interactive** association network describing the rules is generated. As you can see, graphs with many nodes are difficult to read!
            For a more interpretable network, reduce the number of rules and excipients by applying search restrictions. Once the number of excipients goes below eight, 
            bidirectional relationships will be shown in full.
            """)
        
        # Make searchable dataframe
        def filter_dataframe(df: pd.DataFrame) -> pd.DataFrame:
            """
            Adapted from code provided by Streamlit, without handling categorical data.
            Filters the dataframe based on numerical and text input from the user.
            """
            df = df.copy()
            modification_container = st.container()
            with modification_container:
                to_filter_columns = st.multiselect("Filter dataframe on:", df.columns)
                for column in to_filter_columns:
                    left, right = st.columns((1, 20))
                    # Handle numerical columns
                    if is_numeric_dtype(df[column]):
                        _min = float(df[column].min())
                        _max = float(df[column].max())
                        step = (_max - _min) / 100
                        user_num_input = right.slider(
                            f"Values for {column}",
                            min_value=_min,
                            max_value=_max,
                            value=(_min, _max),
                            step=step,
                        )
                        df = df[df[column].between(*user_num_input)]
                    else:
                        # Handle text-based columns
                        user_text_input = right.text_input(
                            f"Substring or regex in {column}",
                        )
                        if user_text_input:
                            df = df[df[column].astype(str).str.contains(user_text_input.upper())]
            return df

        data_ = st.session_state.dataframes["association_rules"]
        data_ = data_[["LHS", "RHS", "support", "confidence", "coverage", "lift", "count"]]
        data_["LHS"] = data_["LHS"].apply(lambda x: str(x).strip("{}").strip())  
        data_["RHS"] = data_["RHS"].apply(lambda x: str(x).strip("{}").strip())  
        data_ = data_.rename(columns={"LHS": "antecedent", "RHS": "consequent"})
        filtered_data = filter_dataframe(data_)
        st.dataframe(filtered_data)
        attribute = st.selectbox(
            "Select edge label:",
            ["lift", "coverage", "confidence", "support"]
        )

        # Graph with pyvis and networkx
        G = nx.MultiDiGraph()
        for _, row in filtered_data.iterrows():
            G.add_edge(
                row["antecedent"], row["consequent"],
                **{attr: row[attr] for attr in ["lift", "coverage", "confidence", "support"]}
            )
        net = Network(height="600px", width="800px", bgcolor="white", font_color="black", directed=True)
        net.from_nx(G)
        for edge in net.edges:
            edge["label"] = str(edge[attribute])

        # Physics
        num_nodes = len(G.nodes)
        net.set_options(f"""
            var options = {{
                "physics": {{
                    "enabled": {str(num_nodes < 8).lower()},
                    "barnesHut": {{
                        "springLength": 200
                    }}
                }},
                "layout": {{
                    "circualr": true
                }},
                "edges": {{
                    "color": {{
                        "highlight": "red"
                    }},
                    "arrows": {{
                        "scaleFactor": 0.1
                    }}
                }}
            }}
        """)

        st.markdown(f"""
            <div style="text-align: center; margin-top: 20px;">
                <h5>Currently displaying {len(G.edges)} rules with {len(G.nodes)} excipients.</h5>
            </div>
        """, unsafe_allow_html=True)
        network_html = net.generate_html()
        st.components.v1.html(network_html, height=600)

    # Two buttons to switch between both functionalities
    col1, col2 = st.columns(2)
    with col1:
        with st.container():
            st.write("")
            if st.button("Explore the Database", use_container_width=True):
                st.session_state.active_tab = "drug_products"
    with col2:
        with st.container():
            st.write("")
            if st.button("Explore Association Rules", use_container_width=True):
                st.session_state.active_tab = "association_rules"

    if st.session_state.get("active_tab") == "association_rules":
        explore_rules()
    elif st.session_state.get("active_tab") == "drug_products":
        explore_database()

    st.markdown("""
        Please note that the data shown in on this page may not be up to date, and should therefore not
        be used for clinical decision-making. Full code and license available on the GitHub repository.
        """)

if __name__ == "__main__":
    main()
