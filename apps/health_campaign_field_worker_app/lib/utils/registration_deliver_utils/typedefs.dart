import 'package:digit_data_model/data_model.dart';


typedef HouseholdDataRepository
    = DataRepository<HouseholdModel, HouseholdSearchModel>;
typedef HouseholdMemberDataRepository
    = DataRepository<HouseholdMemberModel, HouseholdMemberSearchModel>;
typedef ProjectBeneficiaryDataRepository
    = DataRepository<ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>;
typedef TaskDataRepository = DataRepository<TaskModel, TaskSearchModel>;
typedef SideEffectDataRepository
    = DataRepository<SideEffectModel, SideEffectSearchModel>;
typedef ReferralDataRepository
    = DataRepository<ReferralModel, ReferralSearchModel>;
typedef ProjectResourceDataRepository
    = DataRepository<ProjectResourceModel, ProjectResourceSearchModel>;
typedef ProductVariantDataRepository
    = DataRepository<ProductVariantModel, ProductVariantSearchModel>;
